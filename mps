#!/usr/bin/env perl
# $Id: mps,v 1.9 2015/12/15 01:19:51 friedman Exp $

$^W = 1; # enable warnings

use FindBin;
use lib "$FindBin::Bin/../../../lib/perl";
use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;
use Symbol;
use strict;

my @field =             # 1 = right-justify
  ( [qw( user             0 )],
    [qw( pid              1 )],
    [qw( ppid             1 )],
    [qw( pgid             1 )],
    [qw( sid              1 )],
    [qw( lwp              1 )],
    [qw( nlwp=#T          1 )],
    [qw( %cpu             1 )],
    [qw( %mem             1 )],
    [qw( ni               1 )],
    [qw( vsz              1 )],
    [qw( rss              1 )],
    [qw( tty=TTY          0 )],
    [qw( stat=ST          0 )],
    [qw( cpuid=P          1 )],
    [qw( stime            1 )],
    [qw( bsdtime          1 )],
    [qw( context          0 )],
    [qw( comm=LWPNAME     0 )],  # for "mps Hx"
    [qw( args             0 )],
  );

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
  for my $f (@_)
    {
      for (my $i = 0; $i < @field; $i++)
        {
          if (lc $field[$i]->[0] eq lc $f
              || $field[$i]->[0] =~ /^$f=/i)
            {
              splice (@field, $i, 1);
              last;
            }
        }
    }
}

sub fixup_lwpname
{
  my $lines = shift;

  return unless $lines->[0] =~ /\sLWPNAME\s+/;
  my $beg = $-[0] + 1;
  my $end = $+[0] - 2;

  map { my $s = substr ($_, $beg, $end - $beg);
        if ($s =~ /\S\s+\S/)
          {
            $s =~ s/ /_/ while $s =~ /\S\s+\S/;
            substr ($_, $beg, $end - $beg) = $s;
          }
      } @$lines;
}

sub main
{
  delete_field ('context')
    unless $ENV{MPS_CONTEXT} && -d "/sys/fs/selinux/booleans";

  my $show_lwpname = (@_ && $_[0] =~ /^[^-]*H/);
  delete_field ('comm', 'lwp') unless $show_lwpname;

  $ENV{PS_FORMAT} = join (",", field_names());
  $ENV{PS_PERSONALITY} = 'linux';

  push @_, qw(-A) unless (@_);
  unshift @_, qw(ps);

  open (my $fh, "-|", @_) || die "fork: $!\n";
  my @lines = grep { chomp; !/@_|$0/ } <$fh>;
  close ($fh);

  fixup_lwpname (\@lines) if $show_lwpname;

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
