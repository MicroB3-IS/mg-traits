#!/usr/bin/perl

my $FASTQ1 = $ARGV[0];
if (!$FASTQ1) {
  print <<EOD;

print probability of 1 error, 2 error, and 3 errors

Usage: $0 FASTQ_file
Program developed by Weizhong Li's lab: http://weizhongli-lab.org/

EOD
  exit;
  ##### exit
}

my ($len, $p0, $p1, $p2, $p3) = scan_fastq_error($FASTQ1);
print <<EOD;
length	$len
probability of 0 error	$p0
probability of 1 error	$p1
probability of 2 error	$p2
probability of 3 error	$p3
EOD

sub scan_fastq_error {
  my $file = shift;
  my $no = 0;
  my $len = 0;
  my @score = ();
  my @count = ();

  my ($i, $j, $k, $e, $p, $ll);
  open(TMP, $file) || die "can not open $file";
  while($ll=<TMP>){
    if ($ll =~ /^\@/) {
      $ll = <TMP>; #### read sequence
      $ll =~ s/\s//g;
      my $len1 = length($ll);
      if ($len1 > $len) {$len = $len1;}

      $ll = <TMP>; die unless ($ll =~ /^\+/); #### read ID
      $ll = <TMP>; #### read quality score

      for ($i=0; $i<$len1; $i++) {
        my $c1 = ord(substr($ll,$i,1)) - 33;
        $score[$i] += $c1;
        $count[$i]++;
      }
      $no++;

      $i = int(rand()*10)*8; #skip some lines
      $j = 0;
      for ($j=0; $j<$i; $j++) {
        $ll=<TMP>;
        last unless ($ll);
      }
    }
  }
  close(TMP);

  my $p0 = 1;
  for ($i=0; $i<$len; $i++) {
    $ave = $score[$i]/$count[$i];
    $e = 1 / (10 ** ($ave/10));
    $p0 *= (1-$e);
    $score[$i] = $e;
  }
  ## now @score is error probability array

  my $p1 = 0;
  for ($i=0; $i<$len; $i++) {
    $e = $score[$i];
    $p1 += $e * $p0/(1-$e);
  }

  my $p2 = 0;
  for ($i=0; $i<$len; $i++) {
    my $ei = $score[$i];
    for ($j=$i+1; $j<$len; $j++) {
      my $ej = $score[$j];
      $p2 += $ei * $ej * $p0 / (1-$ei) / (1-$ej);
    }
  }

  my $p3 = 0;
  my ($ei, $ej, $ek);
  for ($i=0; $i<$len; $i++) {
    $ei = $score[$i];
    for ($j=$i+1; $j<$len; $j++) {
      $ej = $score[$j];
      for ($k = $j+1; $k<$len; $k++) {
        $ek = $score[$k];
        $p3 += $ei * $ej * $ek *  $p0 / (1-$ei) / (1-$ej) / (1-$ek);
      }
    }
  }

  return ($len, $p0, $p1, $p2, $p3);
}
############# END scan_fastq


