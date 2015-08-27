#!/usr/bin/env perl
# $Id: mps,v 1.7 2011/10/10 05:10:14 friedman Exp $

$^W = 1; # enable warnings

use FindBin;
use lib "$FindBin::Bin/../../../lib/perl";
use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;
use Symbol;
use strict;

my @field =     # 1 = right-justify
  ( [qw( user     0 )],
    [qw( pid      1 )],
    [qw( ppid     1 )],
    [qw( nlwp=#T  1 )],
    [qw( %cpu     1 )],
    [qw( %mem     1 )],
    [qw( ni       1 )],
    [qw( vsz      1 )],
    [qw( rss      1 )],
    [qw( tty=TTY  0 )],
    [qw( stat=ST  0 )],
    [qw( cpuid=P  1 )],
    [qw( stime    1 )],
    [qw( bsdtime  1 )],
    [qw( context  0 )],
    [qw( args     0 )] );

sub field_names
{
  map { $_->[0] } @field;
}

sub field_rjustify
{
  my $i = 0;
  map { $i++ => $_->[1] } @field;
}

sub delete_field
{
  for (my $i = 0; $i < @field; $i++)
    {
      return splice (@field, $i, 1)
        if $field[$i]->[0] eq $_[0];
    }
}

sub main
{
  delete_field ('context')
    unless $ENV{MPS_CONTEXT} && -d "/sys/fs/selinux/booleans";

  $ENV{PS_FORMAT} = join (',', field_names());
  $ENV{PS_PERSONALITY} = 'linux';

  push @_, qw(-A) unless (@_);
  unshift @_, qw(ps);

  open (my $fh, "-|", @_) || die "fork: $!\n";
  my @lines = grep { chomp; !/@_|$0/ } <$fh>;
  close ($fh);

  my $fmt = NF::FmtCols->new
    ( output_style            => 'plain',
      skip_leading_whitespace => 1,
      num_fields              => scalar @field,
      right_justify           => { field_rjustify() },
    );
  $fmt->read_from_array (\@lines);
  $fmt->output;
}

main (@ARGV);

# eof
