#!/usr/bin/perl

my $offset=shift;
my $e_cutoff=shift; # 0.001
my $q_cutoff=int(10 * log(1/$e_cutoff) / log(10));

my $no = 0;
my $no_bad = 0;
my $len = 0;
my @score = ();
my @count = ();
my $id = "";

while($ll=<>){
  if ($ll =~ /^\@/) {
    $id = $ll;
    $ll = <>; #### read sequence
    $ll =~ s/\s//g; 
    my $len1 = length($ll);
    if ($len1 > $len) {$len = $len1;}

    $ll = <>; die unless ($ll =~ /^\+/); #### read ID
    $ll = <>; #### read quality score

    $len2 = $len1*0.8;

    my $cc=0;
    for ($i=0; $i<$len2; $i++) {
      my $c1 = ord(substr($ll,$i,1)) - $offset;
      if ($c1 < $q_cutoff) {$cc++;}
      $score[$i] += $c1;
      $count[$i]++;
    }
    if ($cc > 20) {$no_bad++;}

    $no++;
    if ($no %10000 == 0) { print "$no\t$no_bad\n";}
  }
}

print "$no\t$no_bad\n";

my $p1 = 1;
for ($i=0; $i<$len; $i++) {
  $ave = $score[$i]/$count[$i];
  $e = 1 / (10 ** ($ave/10));
  $p = 1-$e;

  $p1 *= $p;

  # for print only
  $e = int($e*1000000)/1000000;
  $p = int($p*1000000)/1000000;
  $p1 = int($p1*1000000)/1000000;
  print "$i\t$score[$i]\t$count[$i]\t$ave\t$e\t$p\t$p1\n";

}




