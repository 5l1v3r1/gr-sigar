 /*
	gr-scan - A GNU Radio signal scanner
	Copyright (C) 2015 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
	Copyright (C) 2012  Nicholas Tomlinson

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <csignal>
#include <ctime>
#include <set>
#include <utility>
#include <vector>
#include <boost/shared_ptr.hpp>
#include <experimental/filesystem>

#include <gnuradio/top_block.h>
#include <gnuradio/block.h>
#include <gnuradio/io_signature.h>
#include <gnuradio/blocks/file_sink.h>
#include <osmosdr/source.h>


class scanner_sink : public gr::block
{
public:
	scanner_sink(osmosdr::source::sptr source, unsigned int vector_length, double centre_freq_1,
		     double centre_freq_2, double bandwidth0, double bandwidth1, double bandwidth2,
		     double step, unsigned int avg_size, double spread, double threshold, double ptime,
		     gr::blocks::file_meta_sink::sptr fs, gr::blocks::throttle::sptr thr,
				 const std::string &outcsv) :
		gr::block("scanner_sink",
			  gr::io_signature::make(1, 1, sizeof (float) * vector_length),
			  gr::io_signature::make(0, 0, 0)),
		m_source(source), //We need the source in order to be able to control it
		m_buffer(new float[vector_length]), //buffer into which we accumulate the total for averaging
		m_vector_length(vector_length), //size of the FFT
		m_count(0), //number of FFTs totalled in the buffer
		m_wait_count(0), //number of times we've listenned on this frequency
		m_avg_size(avg_size), //the number of FFTs we should average over
		m_step(step), //the amount by which the frequency shold be incremented
		m_centre_freq_1(centre_freq_1), //start frequency (and then current frequency)
		m_centre_freq_2(centre_freq_2), //end frequency
		m_bandwidth0(bandwidth0), //samples per second
		m_bandwidth1(bandwidth1), //fine window (band)width
		m_bandwidth2(bandwidth2), //coarse window (band)width
		m_threshold(threshold), //threshold in dB for discovery
		m_spread(spread), //minumum distance between radio signals (overlapping scans might produce slightly different frequencies)
		m_time(ptime), //the amount of time to listen on the same frequency for
		m_start_time(time(0)), //the start time of the scan (useful for logging/reporting/monitoring)
		m_fs(fs),
		m_thr(thr),
		m_outcsv(NULL)
	{
		ZeroBuffer();
		// Create directory for the IQ files, if outcsv is not empty, chech csv directory
	  create_run_dirs(!outcsv.empty());
		std::remove("blank.bin.hdr"); // Clean up from initialization of file meta sink
		std::remove("blank.bin");
		m_work_done = false;
		if (!outcsv.empty()) {
			bool write_csv_header = access((m_run_info + outcsv).c_str(), F_OK) == -1;
			m_outcsv = fopen((m_csv_dir+m_run_info+outcsv).c_str(), "a+");
			if (!m_outcsv) {
				fprintf(stderr, "[-] Error opening output CSV file %s\n", outcsv.c_str());
				exit(1);
			}
			if (write_csv_header) {
				fprintf(m_outcsv, "time,frequency_mhz,width_khz,peak,dif,filename,mod_type\n");
				fflush(m_outcsv);
			}
		}
	}

	virtual ~scanner_sink()
	{
		delete []m_buffer; //delete the buffer
		if (m_outcsv)
			fclose(m_outcsv);
	}

private:
	virtual int general_work(int noutput_items, gr_vector_int &ninput_items, gr_vector_const_void_star &input_items, gr_vector_void_star &output_items)
	{
		for (int i = 0; i < ninput_items[0]; ++i)
			ProcessVector(static_cast<const float *>(input_items[0]) + i * m_vector_length);

		consume_each(ninput_items[0]);
		if (m_work_done)
		{
			/*Returning -1 signals to the gnuradio scheduler that all work is done.
				Doing so will cleanly shutdown the flow graph, exit normally, and bring
				about world peace. However, because there is a fork in the connections,
				one path goes to a file sink and one to a this sink, gnuradio can't
				handle propagating the WORK_DONE signal to the other branch and a
				segfault occurs. This entire API is held together with duct tape and
				wishful thinking. I mean holy hell, how friggin hard is it to exit a
				process cleanly? And all the scheduler would have to do is pass WORK_DONE
				to the top_block and then the top_block would immediately discconect the
				blocks. *MINDBLOWN* Where's my Nobel, because clearly I'm thinking on
				a totally different level. I'm playing 67D, underwater connect four over
				here.
			*/
			//return -1;
			return 0;
		}
		else
		{
			return 0;
		}
	}

	void ProcessVector(const float *input)
	{
		//Add the FFT to the total
		for (unsigned int i = 0; i < m_vector_length; ++i)
			m_buffer[i] += input[i];
		++m_count; //increment the total

		if (m_avg_size != m_count)
			return; //we haven't yet averaged over the number we intended to

		double freqs[m_vector_length]; //for convenience
		float bands0[m_vector_length]; //bands in order of frequency
		float bands1[m_vector_length]; //fine window bands
		float bands2[m_vector_length]; //coarse window bands

		Rearrange(bands0, freqs, m_centre_freq_1, m_bandwidth0); //organise the buffer into a convenient order (saves to bands0)
		GetBands(bands0, bands1, m_bandwidth1); //apply the fine window (saves to bands1)
		GetBands(bands0, bands2, m_bandwidth2); //apply the coarse window (saves to bands2)
		PrintSignals(freqs, bands1, bands2);

		m_count = 0; //next time, we're starting from scratch - so note this
		ZeroBuffer(); //get ready to start again
		++m_wait_count; //we've just done another listen
		if (m_time / (m_bandwidth0 / static_cast<double>(m_vector_length * m_avg_size)) <= m_wait_count) { //if we should move to the next frequency
			for (;;) { //keep moving to the next frequency until we get to one we can listen on (copes with holes in the tunable range)
				if (m_centre_freq_2 <= m_centre_freq_1) { //we reached the end!
					fprintf(stderr, "\n[*] Finished scanning\n"); //say we're exiting
					m_work_done = true;
					//break;
					/*Ham-fisted, bull-in-a-china-shop solution to closing because
						gnuradio wants to crush any remaining hope out of your pathetic
						existence.
					*/
					exit(0);
				}
				m_centre_freq_1 += m_step; //calculate the frequency we should change to
				double actual = m_source->set_center_freq(m_centre_freq_1); //change frequency
				if ((m_centre_freq_1 - actual < 10.0) && (actual - m_centre_freq_1 < 10.0)) //success
					break; //so stop changing frequency
			}
			m_wait_count = 0; //new frequency - we've listened 0 times on it
		}
	}

	void PrintSignals(double *freqs, float *bands1, float *bands2)
	{
		/* Calculate the current time after start */
		unsigned int t = time(NULL) - m_start_time;
		unsigned int hours = t / 3600;
		unsigned int minutes = (t % 3600) / 60;
		unsigned int seconds = t % 60;

		//Print that we finished scanning something
		fprintf(stderr, "\n%02u:%02u:%02u: Finished scanning %f MHz - %f MHz",
			hours, minutes, seconds, (m_centre_freq_1 - m_bandwidth0 / 2.0) / 1000000.0, (m_centre_freq_1 + m_bandwidth0 / 2.0) / 1000000.0);

		/* Calculate the differences between the fine and coarse window bands */
		float diffs[m_vector_length];
		for (unsigned int i = 0; i < m_vector_length; ++i)
			diffs[i] = bands1[i] - bands2[i];

		/* Look through to find signals */
		//start with no signal found (note: diffs[0] should always be very negative because of the way the windowing function works)
		bool sig = false;
		unsigned int peak = 0;
		for (unsigned int i = 0; i < m_vector_length; ++i) {
			if (sig) { //we're already in a signal
				if (diffs[peak] < diffs[i]) //we found a rough end to the signal
					peak = i;

				if (diffs[i] < m_threshold) { //we're transitionning to the end
					/* look for the "start" of the signal */
					unsigned int min = peak; //scan outwards for the minimum
					while ((diffs[min] > diffs[peak] - 3.0) && (min > 0)){ //while the signal is still more than half power
						min--;
					}

					/* look for the "end" */
					unsigned int max = peak;
					while ((diffs[max] > diffs[peak] - 3.0) && (max < m_vector_length - 1))
						max++;
					sig = false; //we're now in no signal state

					/* Print the signal if it's a genuine hit */
					if (TrySignal(freqs[max], freqs[min])) {
						fprintf(stderr, "\n[+] %02u:%02u:%02u: Found signal: at %f MHz of width %f kHz, peak power %f dB (difference %f dB) ",
							hours, minutes, seconds, (freqs[max] + freqs[min]) / 2000000.0, (freqs[max] - freqs[min])/1000.0, bands1[peak], diffs[peak]);
						WriteCSV((freqs[max] + freqs[min]) / 2000000.0,
							 (freqs[max] - freqs[min])/1000.0,
							 bands1[peak], diffs[peak]);
					}
				}
			}
			else if (diffs[i] >= m_threshold) { //we found a signal!
				peak = i;
				sig = true;
			}
		}
	}

	bool TrySignal(double min, double max)
	{
		double mid = (min + max) / 2.0; //calculate the midpoint of the signal

		/* check to see if the signal is too close to the centre frequency (a signal often erroniously appears there) */
		if ((mid - m_centre_freq_1 < m_spread) && (m_centre_freq_1 - mid < m_spread))
			return false; //if so, this is not a genuine hit

		/* check to see if the signal is close to any other (the same signal often appears with a slightly different centre frequency) */
		BOOST_FOREACH (double signal, m_signals){
			if ((mid - signal < m_spread) && (signal - mid < m_spread)) //tpo close
				return false; //if so, this is not a genuine hit
		}

		/* Genuine hit!:D */
		m_signals.insert(mid); //add to the set of signals
		return true; //genuine hit
	}

	void Rearrange(float *bands, double *freqs, double centre, double bandwidth)
	{
		double samplewidth = bandwidth/(double)m_vector_length;
		for (unsigned int i = 0; i < m_vector_length; ++i) {
			/* FFT is arranged starting at 0 Hz at the start, rather than in the middle */
			if (i < m_vector_length / 2) //lower half of the fft
				bands[i + m_vector_length / 2] = m_buffer[i] / static_cast<float>(m_avg_size);
			else //upper half of the fft
				bands[i - m_vector_length / 2] = m_buffer[i] / static_cast<float>(m_avg_size);

			freqs[i] = centre + i * samplewidth - bandwidth / 2.0; //calculate the frequency of this sample
		}
	}

	void GetBands(float *powers, float *bands, unsigned int bandwidth)
	{
		double samplewidth = m_bandwidth0 / static_cast<double>(m_vector_length); //the width in Hz of each sample
		unsigned int bandwidth_samples = bandwidth / samplewidth; //the number of samples in our window
		for (unsigned int i = 0; i < m_vector_length; ++i) //we're averaging, so start with 0
			bands[i] = 0.0;

		for (unsigned int i = 0; i < m_vector_length; ++i){ //over the entire FFT
			//make the buffer contains the entire window
			if ((i >= bandwidth_samples / 2) && (i < m_vector_length + bandwidth_samples / 2 - bandwidth_samples)){
				for (unsigned int j = 0; j < bandwidth_samples; ++j) //iterate over the window for averaging
					bands[i + j - bandwidth_samples / 2] += powers[i] / static_cast<float>(bandwidth_samples); //add this sample to the bands
			}
		}
	}

	void ZeroBuffer()
	{
		/* writes zeros to m_buffer */
		for (unsigned int i = 0; i < m_vector_length; ++i)
			m_buffer[i] = 0.0;
	}

	void WriteCSV(float freq, float width, float peak, float diff)
	{
		time_t timer;
		struct tm *tm_info;
		char buf[26];
		char time_stamp[7];

		if (!m_outcsv)
			return;

		time(&timer);
		tm_info = localtime(&timer);
		strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", tm_info);
		strftime(time_stamp, 7, "%H%M%S", tm_info);
		// Record IQ data and return name of file
		std::string filename = RecordIQ(freq, width, time_stamp);
		fprintf(m_outcsv, "%s,%f,%f,%f,%f,%s,%s\n", buf, freq, width, peak, diff, filename.c_str(), "unk");
		fflush(m_outcsv);
	}

	void create_run_dirs(bool csv)
		{
			char dat[10]; // Date
			char ts[7];   // time stamp
			strftime(dat, 10, "%d%b%Y", localtime(&m_start_time)); // Format date
			strftime(ts, 7, "%H%M%S", localtime(&m_start_time));   // Format time stamp

			std::string bin_dir = "bin_files";              					 // Main bin directory
			m_csv_dir = "csv_files/";																	 // Directory for CSV file
			std::string soi_dir = "SOI_";                 						// Daily runs
			soi_dir.append(dat);                           						// Append date
			std::string run_dir = "run_";                 						// Individual run directory
			run_dir.append(ts);                            						// append time stamp
			m_iq_dir = bin_dir + "/" + soi_dir + "/" + run_dir + "/"; // Complete file path
			m_run_info = soi_dir + "-" + run_dir + "-";								// CSV file prefix

	    // Check to see if daily directory exists
			if (!std::experimental::filesystem::is_directory(bin_dir + "/" + soi_dir))
			{
				// Make sure main directory exists
				if(!std::experimental::filesystem::is_directory(bin_dir))
				{
					// Create main directory if absent
					std::experimental::filesystem::create_directory(bin_dir);
				}
				// Create daily directory if absent
				std::experimental::filesystem::create_directory(bin_dir + "/" +soi_dir);
			}
			// Create run directory
			std::experimental::filesystem::create_directory(m_iq_dir);

			// csv will be true if an output csv file was specified, so we should check
			// the existence of the csv_directory
			if ((csv) && (!std::experimental::filesystem::is_directory(m_csv_dir)))
			{
				std::experimental::filesystem::create_directory(m_csv_dir);
			}
		}

	std::string RecordIQ(float frq, float bw, char clk_time[7])
	{
		m_source->set_center_freq(frq*1000000);  // Set source to current freq
		m_source->set_sample_rate(bw*2000);      // Set sample rate to twice bw
		m_thr->set_sample_rate(bw*2000);         // Set throttle to sample rate
		// Generate filename
		std::string file_name = m_iq_dir + std::to_string(frq) + "-" + std::to_string(bw)+"_";
		file_name.append(clk_time);               // Append time stamp
		m_fs->open(file_name + ".bin");           // Tell file sink to open a file
		sleep(2);                                // Wait two seconts
		m_fs->close();                           // Tell file sink to close file
		m_source->set_sample_rate(m_bandwidth0); // Reset source bw
		m_thr->set_sample_rate(m_bandwidth0);    // Reset throttle bandwidth
		return (file_name+".bin");                // Return filename
	}

	bool m_work_done;
	std::string m_iq_dir;
	std::string m_csv_dir;
	std::string m_run_info;
	std::set<double> m_signals;
	osmosdr::source::sptr m_source;
	float *m_buffer;
	unsigned int m_vector_length;
	unsigned int m_count;
	unsigned int m_wait_count;
	unsigned int m_avg_size;
	double m_step;
	double m_centre_freq_1;
	double m_centre_freq_2;
	double m_bandwidth0;
	double m_bandwidth1;
	double m_bandwidth2;
	double m_threshold;
	double m_spread;
	double m_time;
	time_t m_start_time;
	gr::blocks::file_meta_sink::sptr m_fs; //define file_sink
	gr::blocks::throttle::sptr m_thr; // throttle
	FILE *m_outcsv;
};

/* Shared pointer thing gnuradio is fond of */
typedef boost::shared_ptr<scanner_sink> scanner_sink_sptr;
scanner_sink_sptr make_scanner_sink(osmosdr::source::sptr source, unsigned int vector_length, double centre_freq_1, double centre_freq_2, double bandwidth0, double bandwidth1, double bandwidth2, double step, unsigned int avg_size, double spread, double threshold, double ptime, gr::blocks::file_meta_sink::sptr fs, gr::blocks::throttle::sptr thr, const std::string &outcsv)
{
	return boost::shared_ptr<scanner_sink>(new scanner_sink(source, vector_length, centre_freq_1, centre_freq_2, bandwidth0, bandwidth1, bandwidth2, step, avg_size, spread, threshold, ptime, fs, thr, outcsv));
}
