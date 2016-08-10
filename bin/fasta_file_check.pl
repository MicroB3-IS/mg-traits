#!/usr/bin/perl

use Bio::SeqIO;

$in = Bio::SeqIO->new(-file => "$ARGV[0]", '-format' => 'Fasta');
$out = Bio::SeqIO->new(-file => ">$ARGV[1]", '-format' => 'Fasta');

while (my $seq = $in->next_seq) {
  if ($seq->validate_seq($seq->seq) == 0 ){
     $out->write_seq($seq);
     exit(1);
  } elsif ($seq->length < 10){
     $out->write_seq($seq);
     exit(2);
  }
}

