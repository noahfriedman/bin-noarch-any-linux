#!/usr/bin/env perl
# $Id: mps,v 1.3 2010/02/22 11:54:58 friedman Exp $

$^W = 1; # enable warnings

use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;
use Symbol;
use strict;

my %field =
  ( 'user'    => { order =>  1, rjustify => 1, },
    'pid'     => { order =>  2, rjustify => 1, },
    'ppid'    => { order =>  3, rjustify => 1, },
    'nlwp=#T' => { order =>  4, rjustify => 1, },
    '%cpu'    => { order =>  5, rjustify => 1, },
    '%mem'    => { order =>  6, rjustify => 1, },
    'ni'      => { order =>  7, rjustify => 1, },
    'vsz'     => { order =>  8, rjustify => 1, },
    'rss'     => { order =>  9, rjustify => 0, },
    'tty=TTY' => { order => 10, rjustify => 0, },
    'stat=ST' => { order => 11, rjustify => 1, },
    'cpuid=P' => { order => 12, rjustify => 0, },
    'stime'   => { order => 13, rjustify => 1, },
    'bsdtime' => { order => 14, rjustify => 0, },
    'context' => { order => 15, rjustify => 0, },
    'args'    => { order => 16, rjustify => 0, },
  );

sub field_names
{
  sort { $field{$a}->{order} <=> $field{$b}->{order} } keys %field;
}

sub field_rjustify
{
  map { $field{$_}->{rjustify} } field_names();
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

  my $fmt = NF::FmtCols->new;
  $fmt->output_style ('plain');
  $fmt->add_right_justify (field_rjustify());
  $fmt->num_fields (scalar keys %field);
  $fmt->read_from_array (\@lines);
  $fmt->output;
}

main (@ARGV);

# eof
