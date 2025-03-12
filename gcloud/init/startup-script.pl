#!/usr/bin/perl -w
#
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

use v5.38;
use POSIX qw(strftime);

#
# Dataproc Pre-Startup
# AKA GCE Linux VM Startup script
# Example script follows
#
# https://cloud.google.com/compute/docs/instances/startup-scripts/linux
#
# startup-script-perl
#

use File::Temp qw/ tempdir  /;
my $template = q{/tmp/prestartup-script-XXXXXXXX};
my $TMPDIR = tempdir ( $template, CLEANUP => 0 );
my $LOGFILE = qq{${TMPDIR}/prestartup-script.log};

open(my($log_fh), q{>}, qq{${LOGFILE}}) or warn qq{cannot open logfile for write};
sub log_msg {
  print $log_fh strftime(q{%F %T %z> }, localtime), qq{@_}, $/;
}

log_msg qq{script start};

# script goes here

log_msg qq{script end};

#
# Startup script ends
#
