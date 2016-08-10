#!/usr/bin/perl

my $clstr = shift;

my %existing_ids = ();

my ($i, $j, $k);
open(TMP, $clstr) || die "can not open $clstr";

while($ll=<TMP>){
  if ($ll =~ /^>/) {
    ;
  }
  else {
    chop($ll);
    my $rep = "";
    my $id = "";
    if ($ll =~ /(\d+)(aa|nt), >(.+)\.\.\./) {
      $rep = $3;
      if ($rep =~ /^(.+)\.contig.\d+/) {
        $id = $1;
        if (not defined($existing_ids{$id})) {
          $existing_ids{$id}=1;
        }
        else {
          print "$rep\n";
        }
      }
    }
  }
}
close(TMP);


