#!/usr/bin/env perl
# The machine's cheap vitals for services/Metrics: one long-lived process that reads them every INTERVAL ms and prints
# one JSON line each time. No process per sample, and none of the debug lines a FileView reload writes to the shell's
# detailed log (three per file per read: about 45 MB a day of RAM at one read a second).
#   metrics.pl INTERVAL [SENSOR_FILE ...]
# A line: {"stat": [[idle, total], ...]   /proc/stat's cpu lines (all, then each thread): idle + iowait, and the sum of
#                                         user nice system idle iowait irq softirq steal, in ticks
#          "mem": [total, available]      /proc/meminfo, kB
#          "iface": "wlp4s0"              the default route's interface (/proc/net/route), "" for none
#          "net": [rx, tx]                its bytes so far (/proc/net/dev), null without an interface
#          "sensors": [v, ...]}           each SENSOR_FILE's number (hwmon), null when unreadable
# The shell keeps the differences (cpu %, bytes per second). It ends with the shell: its next line meets a closed pipe.
use strict;
use warnings;
use Time::HiRes qw(time sleep);

$| = 1;
my ($interval, @sensors) = @ARGV;
$interval = ($interval || 1000) / 1000;

sub slurp {
    open(my $h, '<', $_[0]) or return undef;
    local $/;
    my $text = <$h>;
    close $h;
    return $text;
}

my $next = time;
while (1) {
    my @stat;
    for (split /\n/, slurp('/proc/stat') // '') {
        next unless /^cpu\d* /;
        my @f = map { $_ // 0 } (split ' ')[1 .. 8];
        my $total = 0;
        $total += $_ for @f;
        push @stat, '[' . ($f[3] + $f[4]) . ",$total]";
    }
    my $meminfo = slurp('/proc/meminfo') // '';
    my ($memTotal) = $meminfo =~ /^MemTotal:\s+(\d+)/m;
    my ($memAvailable) = $meminfo =~ /^MemAvailable:\s+(\d+)/m;
    my $iface = '';
    for (split /\n/, slurp('/proc/net/route') // '') {
        my @f = split ' ';
        if (@f > 1 && $f[1] eq '00000000') { $iface = $f[0]; last; }
    }
    my $net = 'null';
    if ($iface ne '') {
        for (split /\n/, slurp('/proc/net/dev') // '') {
            next unless /^\s*\Q$iface\E:\s*(.*)$/;
            my @f = split ' ', $1;
            $net = "[$f[0],$f[8]]";
            last;
        }
    }
    my @values = map { my $v = slurp($_); defined $v && $v =~ /^\s*(-?\d+(?:\.\d+)?)\s*$/ ? $1 : 'null' } @sensors;
    print '{"stat":[' . join(',', @stat) . '],"mem":[' . ($memTotal // 0) . ',' . ($memAvailable // 0)
        . '],"iface":"' . $iface . '","net":' . $net . ',"sensors":[' . join(',', @values) . "]}\n";

    # On a fixed beat (a slow read does not push the next one back), and never two at once after a stall.
    $next += $interval;
    my $wait = $next - time;
    if ($wait > 0) { sleep $wait } else { $next = time }
}
