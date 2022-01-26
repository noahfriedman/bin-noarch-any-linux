#!/usr/bin/env perl

use strict;
use warnings;
no  warnings qw(qw);

use FindBin;
use lib "$FindBin::Bin/../../../lib/perl";
use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;
use POSIX;

# Meaning of columns:
#    1:  1 = right-justify
#    2:  h = convert to human-readable units
#    3:  multiplier (if any) for values before human-scaling
my @field =
  ( [qw( user             0   )],
    [qw( pid              1   )],
    [qw( ppid             1   )],
    [qw( pgid             1   )],
    [qw( sid              1   )],
    [qw( lwp              1   )],
    [qw( nlwp=#T          1   )],
    [qw( %cpu             1   )],
    [qw( %mem             1   )],
    [qw( ni               1   )],
    [qw( vsz              1 h 1024 )], # raw is kib
    [qw( rss              1 h 1024 )], # raw is kib
    [qw( tty=TTY          0   )],
    [qw( wchan:32         0   )],
    [qw( stat=ST          0   )],
    [qw( cpuid=P          1   )],
    [qw( stime            1   )],
    [qw( bsdtime          1   )],
    [qw( context          0   )],
    [qw( comm:32=LWPNAME  0   )],  # for "mps Hx"
    [qw( args             0   )],
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
              || $field[$i]->[0] =~ /^$f[:=]/i)
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

sub fixup_hreadable
{
  my $fmt = shift;

  for (my $f = 0; $f < @field; $f++)
    {
      my $h = $field[$f]->[2];
      next unless $h && $h eq 'h';

      my $scale = $field[$f]->[3] || 1;
      map { $_->[$f] = scale_size ($scale * $_->[$f], undef, undef, 1)
              if $_->[$f] =~ /^\d+$/;
          } @{$fmt->row_data};
    }
  $fmt->recalculate;
}

sub scale_size
{
  my ($size, $roundp, $fp, $minimize) = @_;
  return "0" unless $size;

  my $fmtsize = 1024; # no SI handling here
  my @suffix = (qw(B K M G T P E));
  my %suffix = map { $_ => undef } @suffix;
  my $idx    = 0;

  while ($size >= $fmtsize)
    {
      $size /= $fmtsize;
      $idx++;
    }

  if ($size < 10 && !$minimize) # Prefer 4096M to 4G
    {
      $size *= $fmtsize;
      $idx--;
    }

  $size = POSIX::round( $size ) if $roundp;
  $size = int( $size ) if $size == int( $size );

  my $unit;
  if ($idx == 0) { $unit = '' }
  else { $unit = $suffix[$idx] }

  my $fmtstr = ($size == int( $size )
                ? "%d%s"
                : sprintf( "%%.%df%%s", $fp || 2));
  return sprintf( $fmtstr, $size, $unit );
}

sub match_any
{
  my $re = shift;
  map { return 1 if $_ =~ $re } @_;
  return 0;
}

sub main
{
  delete_field ('context')
    unless $ENV{MPS_CONTEXT} && -d "/sys/fs/selinux/booleans";

  my $show_lwpname = match_any (qr/^[^-]*H/, @_);
  delete_field ('comm', 'lwp', 'wchan') unless $show_lwpname;

  $ENV{PS_FORMAT} = join (",", field_names());
  $ENV{PS_PERSONALITY} = 'linux';

  push @_, qw(-A) unless (@_);
  unshift @_, qw(ps);

  open (my $fh, "-|", @_) || die "fork: $!\n";
  my $childstr = quotemeta ("@_");
  my @lines = grep { chomp; !/$childstr|$0/ } <$fh>;
  close ($fh);

  fixup_lwpname (\@lines) if $show_lwpname;

  my $fmt = NF::FmtCols->new
    ( output_style            => 'plain',
      skip_leading_whitespace => 1,
      num_fields              => scalar @field,
      right_justify           => { field_rjustify() },
    );
  $fmt->read_from_array (\@lines);
  fixup_hreadable ($fmt);
  $fmt->output;
}

main (@ARGV);

# eof
