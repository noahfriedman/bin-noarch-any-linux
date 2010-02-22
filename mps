#!/usr/bin/env perl
# $Id$

$^W = 1; # enable warnings

use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;
use Symbol;
use strict;

my @field
  = qw(user
       pid
       ppid
       nlwp=#T
       %cpu
       %mem
       ni
       vsz
       rss
       tty=TTY
       stat=ST
       cpuid=P
       stime
       bsdtime
       args);

sub startproc
{
  my ($rfh, $wfh) = (gensym, gensym); # readhandle, writehandle
  pipe ($rfh, $wfh);

  my $pid = fork;
  die "fork: $!\n" unless defined $pid;

  if ($pid == 0) # child
    {
      open (*STDOUT{IO}, ">&" . fileno ($wfh));
      close ($rfh);
      close ($wfh);
      local $SIG{__WARN__} = sub { 0 };
      exec (@_) || die "exec: $_[0]: $!";
    }
  else
    {
      close ($wfh);
      return $rfh;
    }
}

sub main
{
  $ENV{PS_FORMAT} = join (',', @field);
  $ENV{PS_PERSONALITY} = 'linux';

  push @_, qw(-A) unless (@_);
  my @pscmd = qw(ps);
  push @pscmd, @_;

  my $fh = startproc (@pscmd);
  my @lines = grep { chomp; !/@pscmd|$0/ } <$fh>;
  close ($fh);
  wait;

  my $fmt = NF::FmtCols->new;
  $fmt->output_style ('plain');
  $fmt->add_right_justify (1, 2, 3, 4, 5, 6, 7, 8, 11, 13);
  $fmt->num_fields (scalar @field);
  $fmt->read_from_array (\@lines);
  $fmt->output;

}

main (@ARGV);

# eof
