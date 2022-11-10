echo 1 > /sys/kernel/debug/tracing/events/netfs/enable
echo 1 > /sys/kernel/debug/tracing/events/fscache/enable
echo 1 > /sys/kernel/debug/tracing/events/cachefiles/enable
echo 1 > /sys/kernel/debug/tracing/events/erofs/enable
echo 1 > /sys/kernel/debug/tracing/tracing_on
cat /sys/kernel/debug/tracing/trace_pipe
