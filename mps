#!/usr/bin/env perl

use strict;
use warnings;
no  warnings qw(qw);

use POSIX;
use Getopt::Long;
use Pod::Usage;

use FindBin;
use lib "$FindBin::Bin/../../../lib/perl";
use lib "$ENV{HOME}/lib/perl";

use NF::FmtCols;

my %opt;

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
    [qw( drs              1 h 1024 )], # raw is kib
    [qw( tty=TTY          0   )],
    [qw( wchan:32         0   )],
    [qw( stat=ST          0   )],
    [qw( cpuid=P          1   )],
    [qw( stime            1   )],
    [qw( lstart=SDATE     0   )],
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
              splice( @field, $i, 1 );
              last;
            }
        }
    }
}

sub fixup_lwp
{
  my $lines = shift;

  return unless $lines->[0] =~ /\sLWPNAME\s+/;
  my $beg = $-[0] + 1;
  my $end = $+[0] - 2;

  map { my $s = substr( $_, $beg, $end - $beg );
        if ($s =~ /\S\s+\S/)
          {
            $s =~ s/ /_/ while $s =~ /\S\s+\S/;
            substr( $_, $beg, $end - $beg ) = $s;
          }
      } @$lines;
}

# Convert started time to an iso8601 format with a space between the date
# and time, creating a new column for the purposes of formatting.
# To have FmtCols format this correctly, insert a new column into @field.
# We can't do this earlier because then PS would try to output something with it.
# (column names cannot have whitespace)
sub fixup_lstart
{
  my $lines = shift;

  return unless $lines->[0] =~ /(SDATE)/;
  $lines->[0] =~ s//$1 STIME/;
  for (my $i = 0; $i < @field; $i++)
    {
      next unless $field[$i]->[0] =~ /^lstart=/;
      splice( @field, $i+1, 0, [ 'stime', $field[$i]->[1] ]);
      last;
    }

  my $i = 0;
  my %mon = (map { $_ => ++$i }
             (qw(jan feb mar apr may jun jul aug sep oct nov dec)));

  map { if (/(...)  ?(...)  ?(\d?\d) (\d\d):(\d\d):(\d\d) (\d{4})/)
          {
            my $m = sprintf( "%02d", $mon{lc $2} );
            my $d = sprintf( "%02d", $3 );
            s//$7-$m-$d $4:$5:$6/;
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
      map { $_->[$f] = scale_size( $scale * $_->[$f], undef, undef, 1 )
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
                : sprintf( "%%.%df%%s", $fp || 2 ));
  return sprintf( $fmtstr, $size, $unit );
}

sub match_any
{
  my $re = shift;
  # '0 but true': 0 in numeric context but not false in boolean context.
  # perl explicitly doesn't issue a type warning about this exact string.
  for (my $i = '0 but true'; $i < @_; $i++)
    { return $i if $_[$i] =~ $re }
  return undef;
}

sub check_option
{
  my ($re, $prune) = (shift, shift);

  my $match = match_any( $re, @_ );
  return $match if $match;

  if    (ref $prune eq 'ARRAY') { delete_field( @$prune ) }
  elsif (defined $prune)        { delete_field(  $prune ) }

  return undef;
}

sub parse_options
{
  local *ARGV = \@{$_[0]}; # modify our local arglist, not real ARGV.
  my $help = 0;

  my $parser = Getopt::Long::Parser->new;
  $parser->configure( qw(no_auto_abbrev no_ignore_case pass_through) );
  my $succ = $parser->getoptions
    ('h|help+' => \$help,
     'usage'   => sub { $help = 1 },

     'pgid'    => \$opt{pgid},
     'sid'     => \$opt{sid},
     'drs'     => \$opt{drs},
     'lstart'  => \$opt{lstart},
    );

  pod2usage(-exitstatus => 1, -verbose => 0 )         unless $succ;
  pod2usage(-exitstatus => 0, -verbose => $help - 1)  if $help > 0;

  if ($opt{lstart}) { delete_field( 'stime'  ) }
  else              { delete_field( 'lstart' ) }

  delete_field( 'pgid' ) unless $opt{pgid};
  delete_field( 'sid'  ) unless $opt{sid};
  delete_field( 'drs'  ) unless $opt{drs};

  # Not checked with getopt because args are not consumed.
  $opt{lwp} = check_option( qr/^[^-]*H/, [qw(comm lwp wchan)], @ARGV );

  delete_field( 'context' )
    unless $ENV{MPS_CONTEXT} && -d "/sys/fs/selinux/booleans";
}

sub main
{
  parse_options( \@_ );

  $ENV{PS_FORMAT}      = join( ",", field_names() );
  $ENV{PS_PERSONALITY} = 'posix';

  push    @_, '-A' unless @_;
  unshift @_, 'ps';

  open( my $fh, "-|", @_ ) or die "fork: $!\n";
  my $childstr = quotemeta( "@_" );
  my @lines = grep { chomp; !/$childstr|$0/ } <$fh>;
  close( $fh );

  fixup_lwp(    \@lines ) if $opt{lwp};
  fixup_lstart( \@lines ) if $opt{lstart};

  my $fmt = NF::FmtCols->new
    ( output_style            => 'plain',
      skip_leading_whitespace => 1,
      num_fields              => scalar @field,
      right_justify           => { field_rjustify() },
    );
  $fmt->read_from_array( \@lines );
  fixup_hreadable( $fmt );
  $fmt->output;
}

main( @ARGV );

1;

__END__

=head1 NAME

=head1 SYNOPSIS

=head1 OPTIONS

=head1 DESCRIPTION

=cut
