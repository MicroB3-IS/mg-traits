#!/usr/bin/perl
$file1 = shift;
$file2 = shift;
$fileo = shift;
$seed_overlap = shift;
$seed_overlap = 35 unless ($seed_overlap);

if ((not $file1) or (not $file2) or (not $fileo)) {
  print <<EOD;
Usage:
$0 file1 file2 seed_overlap
	file1: FASTA file for one end
	file2: FASTA file for another end
	seed_overlap: seed overlap length, default 35
		this is the minimal overlap between the paired reads,
		if the actual overlap is > 35, please use a smaller value
EOD

  exit;
}

open(fl, $file1);
$i = 0;
$str = "";
while($line = <fl>){
   chomp($line);
   if($line =~ /^>(\S+)/){
      if($i > 0){
          $body{$head[$i -1]} = $str;
      }
      $c = $1;
      $head[$i] = $c;
      $str = "";
      $i++;
   }
   else{
      $str .= "$line";
   }
}
if($i > 0){
   $body{$head[$i - 1]} = $str;
}
close(fl);
$counter = $i;

open(fl, $file2);
$i = 0;
$str = "";
while($line = <fl>){
   chomp($line);
   if($line =~ /^>(\S+)/){
      if($i > 0){
          $body2{$head[$i -1]} = $str;
      }
      $c = $1;
      $head2[$i] = $c;
      $str = "";
      $i++;
   }
   else{
      $str .= "$line";
   }
}
if($i > 0){
   $body2{$body[$i - 1]} = $str;
}
close(fl);

my $no = 0;
my $overlap_min = 99999999;
my $overlap_max = 0;
open(OUT, "> $fileo") || die "can not write $fileo";
for($i = 0; $i < $counter; $i++){
   if($body{$head[$i]} ne "" && $body2{$head[$i]} ne ""){
       $tmp = reverse_complement($body2{$head[$i]});         
       $tmp2 = substr($tmp, 0, $seed_overlap);
       $pos = index($body{$head[$i]}, $tmp2);
       $len = length($body{$head[$i]});
       $tmp3 = substr($body{$head[$i]}, $pos, $len - $pos);
       $tmp4 = substr($tmp, 0, $len - $pos);
       if($tmp3 eq $tmp4){
         print OUT ">$head[$i].contig\n";
         #print "$body{$head[$i]}\n";
         #print "$body2{$head[$i]}\n";
         #print "$tmp\n";
         printf OUT "%s\n", $body{$head[$i]} . substr($tmp, $len - $pos, $pos);
         my $len1 = length($tmp3);
         if ($len1 < $overlap_min) {$overlap_min = $len1;}
         if ($len1 > $overlap_max) {$overlap_max = $len1;}
         $no++;
       }
   }
}
close(OUT);

print <<EOD;
total reads: $counter
assembled contigs: $no
max overlap: $overlap_max
min overlap: $overlap_min
EOD

sub reverse_complement {
    my ($in_seq) = @_;
    my $opposite = reverse $in_seq;
    $opposite =~ tr/ACGT/TGCA/;
    return("$opposite");
}

