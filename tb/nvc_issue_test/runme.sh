nvc --std=08 -a ./issue.vhd ; nvc --std=08 -a ./issue_tb.vhd; nvc --std=08 -e issue_tb ; nvc --std=08 -r --stop-time=1000ns --wave=wave.vcd --dump-arrays issue_tb
