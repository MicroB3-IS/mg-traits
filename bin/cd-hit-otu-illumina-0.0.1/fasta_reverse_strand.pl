#!/usr/bin/perl

my $fasta = shift;
my $output = "$fasta.rev";

if (not defined($dev_cutoff)) {$dev_cutoff = 1;}

if (not defined($fasta)) {
   print <<EOD;

Usage $0 fasta-file-DNAs

This script generate fasta file of reverse strand 

EOD
   die;
}
my %code = qw/A T T A G C C G N N/;

open(TMP, $fasta) || die "can not open $fasta\n";
open(OUT, "> $output") || die "can not open $output for writing";
while($ll=<TMP>){
  if ($ll =~ /^>/){
    if ($seq) {
      $seq = rev($seq);
      print OUT $des,$seq,"\n";
    }
    $des = $ll;
    $seq = "";
  }
  else {
    $ll =~ s/\s//g;
    $seq = $seq . $ll;
  } 
}
    if ($seq) {
      $seq = rev($seq);
      print OUT $des,$seq,"\n";
    }
close(TMP);
close(OUT);

sub rev {
  my $seq = shift;
  my $len = length($seq);
  my ($i,$j,$k,$c);
  my $seq1 = "";

  $seq = reverse($seq);
  for ($i=0; $i<$len; $i++){
    $c = substr($seq,$i,1);
    $seq1 .= $code{$c};
  }

  if (length($seq1) ne $len) {
    die "at $seq non ATCGN letter found\n";
  }
  return $seq1;
}

