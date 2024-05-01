# Script used to parse the output of systemd-cgtop and generate a histogram of the memory usage
# Used for resource profiling page in the RKE2 documentation
# Generate input file using the following command:
# systemd-cgtop system.slice/rke2-server.service --raw -b -n 1200 -d 250ms > systemd_cgtop_output.txt
# Pulls data every 0.25s for 5 minutes

# Data arragment is:
# cgroup name, # of tasks, CPU %, MEM usage (bytes)

# import matplotlib.pyplot as plt
import re
import numpy

tasks = []
cpu_usage = []
memory_usage = []
input_file = "systemd_cgtop_output.txt"
cgroup = "rke2-server"

with open(input_file, 'r') as infile:
    # Iterate over each line in the input file
    for line in infile:
        regex = r'system\.slice/' + cgroup
        if re.search(regex, line):
            # Split the line into fields
            fields = line.split()
            # first entry for cpu is blank, so we skip it
            if fields[2] == "-":
                continue
            tasks.append(int(fields[1]))
            cpu_usage.append(float(fields[2]))
            memory_usage.append(int(fields[3])) 

# Convert memory usage to megabytes
memory_usage = [usage / 1024 ** 2 for usage in memory_usage]

tasks_avg = numpy.average(tasks)
cpu_95th = numpy.percentile(cpu_usage, 95)
memory_95th = numpy.percentile(memory_usage, 95)
print(f'Number of Tasks: ', tasks_avg)
print(f'95th Percentile CPU Usage: {cpu_95th:.2f}%')
print(f'95th Percentile Memory Usage: {memory_95th:.2f} MB')

# Optional Plotting
# plt.hist(cpu_usage, bins=20, alpha=0.7, label='CPU Usage')
# plt.hist(memory_usage, bins=20, alpha=0.7, label='Memory Usage')
# plt.axvline(memory_95th, linestyle='dashed', linewidth=1, label=f'95th Percentile Memory ({memory_95th:.2f} MB)')

# plt.xlabel('Usage')
# plt.ylabel('Ticks')
# plt.title('Systemd-cgtop Resource Usage Histogram')
# plt.legend()
# plt.show()



