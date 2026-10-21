#!/bin/sh
# The pairing agent behind the shell's Bluetooth popover (services/BtAgent): bluetoothctl, unbuffered, registered by
# the shell as the default agent. bluetoothctl leaves each agent prompt ("[agent] Confirm passkey 482316 (yes/no): ")
# without a newline while it waits for the answer, and the shell reads lines; so whole lines pass straight through and
# a finished prompt is ended with a newline here. Nothing is answered here: the answers come from the popover.
stdbuf -o0 -e0 bluetoothctl | perl -e '
    $| = 1;
    my $acc = "";
    while (sysread(STDIN, my $chunk, 4096)) {
        $acc .= $chunk;
        while ($acc =~ s/\A([^\n]*\n)//) { print $1 }
        if ($acc =~ /(\(yes\/no\):|Enter PIN code:|\(number in 0-999999\):)\s*\z/) { print "$acc\n"; $acc = "" }
    }'
