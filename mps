#!/usr/bin/env perl
# $Id: mps,v 1.5 2010/11/29 09:01:03 friedman Exp $

$^W = 1; # enable warnings

use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;
use Symbol;
use strict;

my %field =
  ( 'user'    => { order =>  0, rjustify => 0, },
    'pid'     => { order =>  1, rjustify => 1, },
    'ppid'    => { order =>  2, rjustify => 1, },
    'nlwp=#T' => { order =>  3, rjustify => 1, },
    '%cpu'    => { order =>  4, rjustify => 1, },
    '%mem'    => { order =>  5, rjustify => 1, },
    'ni'      => { order =>  6, rjustify => 1, },
    'vsz'     => { order =>  7, rjustify => 1, },
    'rss'     => { order =>  8, rjustify => 1, },
    'tty=TTY' => { order =>  9, rjustify => 0, },
    'stat=ST' => { order => 10, rjustify => 0, },
    'cpuid=P' => { order => 11, rjustify => 1, },
    'stime'   => { order => 12, rjustify => 1, },
    'bsdtime' => { order => 13, rjustify => 1, },
    'context' => { order => 14, rjustify => 0, },
    'args'    => { order => 15, rjustify => 0, },
  );

sub field_names
{
  sort { $field{$a}->{order} <=> $field{$b}->{order} } keys %field;
}

sub field_rjustify
{
  map { $field{$_}->{order} => $field{$_}->{rjustify} } keys %field;
}

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
  unless ($ENV{MPS_CONTEXT} && -d "/selinux/booleans")
    {
      delete $field{context};
    }

  $ENV{PS_FORMAT} = join (',', field_names());
  $ENV{PS_PERSONALITY} = 'linux';

  push @_, qw(-A) unless (@_);
  my @pscmd = qw(ps);
  push @pscmd, @_;

  my $fh = startproc (@pscmd);
  my @lines = grep { chomp; !/@pscmd|$0/ } <$fh>;
  close ($fh);
  wait;

  my $fmt = NF::FmtCols->new
    ( output_style            => 'plain',
      skip_leading_whitespace => 1,
      num_fields              => scalar keys %field,
      right_justify           => { field_rjustify() },
    );
  $fmt->read_from_array (\@lines);
  $fmt->output;
}

main (@ARGV);

# eof
