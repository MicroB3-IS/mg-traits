//=================================================================
// This file is a part of cdhit-dup.
// By Limin Fu (phoolimin@gmail.com, lmfu@ucsd.edu)
//================================================================= 

#include <math.h>
#include <ctype.h>
#include "minString.hxx"
#include "minArray.hxx"
#include "minMap.hxx"
#include "bioSequence.hxx"

using namespace Min;
using namespace Bio;

class SequenceCluster : public Array<Sequence*>
{
	int  id;
	int  abundance;
	int  chiHead;
	int  chiTail;

	public:
	SequenceCluster( Sequence *rep = NULL ){
		id = 0;
		abundance = 0;
		chiHead = chiTail = 0;
		if( rep ) Append( rep );
	}

	String GetDescription( Sequence *seq, int deslen=0 );

	int GetID()const{ return id; }
	void SetID( int i ){ id = i; }

	int GetAbundance()const{ return abundance; }
	void SetAbundance( int ab ){ abundance = ab; }

	int GetChimericParent1()const{ return chiHead; }
	int GetChimericParent2()const{ return chiTail; }
	void SetChimericParent( int head, int tail ){ chiHead = head; chiTail = tail; }

	void Write( FILE *fout = stdout, int id = 0, int deslen=0, const char *des=NULL );

	bool operator<( const SequenceCluster & other ){
		assert( Size() && other.Size() );
		return (*this)[0]->Length() < other[0]->Length();
	}
};
String SequenceCluster::GetDescription( Sequence *seq, int deslen )
{
	String des = seq->Description();
	int i = 0;
	if( des[i] == '>' || des[i] == '@' || des[i] == '+' ) i += 1;
	if( des[i] == ' ' || des[i] == '\t' ) i += 1;
	if( deslen == 0 || deslen > des.Size() ) deslen = des.Size();
	while( i < deslen and ! isspace( des[i] ) ) i += 1;
	des.Resize( i );
	return des;
}
void SequenceCluster::Write( FILE *fout, int id, int deslen, const char *cdes )
{
	//Array<Sequence*> & seqs = *this;
	SequenceCluster & seqs = *this;
	String des = GetDescription( seqs[0], deslen );
	int i = 0, n = Size();

	fprintf( fout, ">Cluster %i%s\n", id, cdes ? cdes : "" );
	fprintf( fout, "%i\t%int, >%s... *\n", 0, seqs[0]->Length(), des.Data() );
	for(i=1; i<n; i++){
		String des = GetDescription( seqs[i], deslen );
		int len = seqs[i]->Length();
		fprintf( fout, "%i\t%int, >%s... at 1:%i:1:%i/+/100.00%%\n", i, len, des.Data(), len, len );
	}
}
void WriteClusters( Array<SequenceCluster> & clusters, const String & name = "temp.txt", int deslen = 0 )
{
	String cfile = name + ".clstr";
	String cfile2 = name + "2.clstr";
	FILE *fout1 = fopen( name.Data(), "w" );
	FILE *fout2 = fopen( cfile.Data(), "w" );
	FILE *fout3 = fopen( cfile2.Data(), "w" );
	char cdes[200];
	int i, n = clusters.Size();
	int k1 = 0, k2 = 0;
	for(i=0; i<n; i++){
		SequenceCluster & cluster = clusters[i];
		int head = cluster.GetChimericParent1();
		int tail = cluster.GetChimericParent2();
		if( cluster.Size() == 0 ) continue;
		if( head == tail ){
			cluster[0]->Print( fout1 );
			cluster.SetID( k1 );
			cluster.Write( fout2, k1++, deslen );
		}else{
			head = clusters[head].GetID();
			tail = clusters[tail].GetID();
			sprintf( cdes, " chimeric_parent1=%i,chimeric_parent2=%i", head, tail );
			cluster.Write( fout3, k2++, deslen, cdes );
		}
	}
	fclose( fout1 );
	fclose( fout2 );
	fclose( fout3 );
}


void SortByAbundance( Array<SequenceCluster> & clusters )
{
	int i, max = 0, min = 0;
	int N = clusters.Size();
	if( N <= 1 ) return;
	max = min = clusters[0].GetAbundance();
	for(i=1; i<N; i++){
		int ab = clusters[i].GetAbundance();
		if( ab > max ) max = ab;
		if( ab < min ) min = ab;
	}

	int M = max - min + 1;
	Min::Array<int> count( M, 0 ); // count for each size = max_len - i
	Min::Array<int> accum( M, 0 ); // count for all size > max_len - i
	Min::Array<int> offset( M, 0 ); // offset from accum[i] when filling sorting
	Array<SequenceCluster> sorted( N );

	for (i=0; i<N; i++) count[ max - clusters[i].GetAbundance() ] ++;
	for (i=1; i<M; i++) accum[i] = accum[i-1] + count[i-1];
	for (i=0; i<N; i++){
		int len = max - clusters[i].GetAbundance();
		int id = accum[len] + offset[len];
		//clusters[i].index = id;
		sorted[id] = clusters[i];
		offset[len] ++;
	}
	clusters.Swap( sorted );
}


int HashingDepth( int len, int min )
{
	assert( len >= min );
	return (int)sqrt( (len - min) / 10);
}
int HashingLength( int dep, int min )
{
	return min + 10 * dep * dep;
}
void ClusterDuplicate( SequenceList & seqlist, Array<SequenceCluster> & clusters, bool mlen )
{
	Array<SequenceCluster*> clusters2;
	Hash<unsigned int,Array<SequenceCluster*> > clustmap;
	Array<Hash<unsigned int,Array<SequenceCluster*> > > clustmaps;
	int max = seqlist.MaxLength();
	int min = seqlist.MinLength();
	int i, j, m, N = seqlist.Count();
	clustmaps.Resize( HashingDepth( max, min ) + 1 );
	for(i=0; i<N; i++){
		Sequence *seq = seqlist[i];
		String & ss = seq->SequenceData();
		int len = seq->Length();
		unsigned int hash = MakeHash( seq->SequenceData() );
		Node<unsigned int,Array<SequenceCluster*> > *node = clustmap.Find( hash );
		bool clustered = false;
		if( node != NULL ){
			Array<SequenceCluster*> & clusts = node->value;
			for(j=0, m=clusts.Size(); j<m; j++){
				SequenceCluster & clust = *clusts[j];
				if( clust.Size() && clust[0]->Length() == len ){
					if( Compare( ss, clust[0]->SequenceData() ) ==0 ){
						clust.Append( seq );
						clustered = true;
						break;
					}
				}
			}
		}
		if( clustered == false && mlen == false ){
			int k, dep = HashingDepth( len, min );
			unsigned int hash = MakeHash( seq->SequenceData(), HashingLength( dep, min ) );
			node = clustmaps[ dep ].Find( hash );
			if( node != NULL ){
				Array<SequenceCluster*> & clusts = node->value;
				for(j=0, m=clusts.Size(); j<m; j++){
					SequenceCluster & clust = *clusts[j];
					if( clust.Size() == 0 || clust[0]->Length() < len ) continue;
					String & rep = clust[0]->SequenceData();
					for(k=0; k<len; k++) if( ss[k] != rep[k] ) break;
					if( k == len ){
						clust.Append( seq );
						clustered = true;
						break;
					}
				}
			}
		}
		if( not clustered ){
			clusters2.Append( new SequenceCluster( seq ) );
			clustmap[ hash ].Append( clusters2.Back() );
			if( mlen == false ){
				int k, dep = HashingDepth( len, min );
				for(k=0; k<=dep; k++){
					hash = MakeHash( seq->SequenceData(), HashingLength( k, min ) );
					clustmaps[k][ hash ].Append( clusters2.Back() );
				}
			}
		}
		if( (i+1)%100000 == 0 )
			printf( "Clustered %9i sequences with %9i clusters ...\n", i+1, clusters2.Size() );
	}
	for(i=0, m=clusters2.Size(); i<m; i++){
		clusters.Append( SequenceCluster() );
		clusters.Back().Swap( *clusters2[i] );
	}
}
struct ChimericSource
{
	int  index;
	int  head;
	int  tail;

	ChimericSource( int i=0, int h=0, int t=0 ){ index = i; head = h; tail = t; }
};
struct HashHit
{
	int  index;
	int  offset;

	HashHit( int i = 0, int o = 0 ){ index = i; offset = o; }
};
typedef Hash<unsigned int,Array<HashHit> >  HashHitTable;

void UpdateHashTables( HashHitTable & heads, Array<HashHitTable> & middles, Sequence *seq, int id, int shared, int min )
{
	unsigned int hash = MakeHash( seq->SequenceData(), shared );
	int j, k;
	heads[hash].Append( HashHit( id, 0 ) );
	for(j=1; (j+shared)<=seq->Length(); j++){
		int dep = HashingDepth( seq->Length()-j, min );
		for(k=0; k<=dep; k++){
			hash = MakeHash( seq->SequenceData(), j, HashingLength( k, min ) );
			middles[k][hash].Append( HashHit( id, j ) );
		}
	}
}
void DetectChimeric( Array<SequenceCluster> & clusters, Array<ChimericSource> & chistat, int max, int shared, int minabu = 2 )
{
	unsigned int hash;
	int i, j, k, K, K2, M, N = clusters.Size();
	int min = shared, count = 0;
	Hash<unsigned int,Array<HashHit> > heads;
	Array<Hash<unsigned int,Array<HashHit> > > middles;
	Node<unsigned int,Array<HashHit> > *node;

	middles.Resize( HashingDepth( max, min ) + 1 );
	printf( "Searching for chimeric clusters ...\n" );
	for(i=0; i<N; i++){
		Sequence *seq = clusters[i][0];
		int qn = clusters[i].GetAbundance();

		if( qn < minabu ) break;
		if( seq->Length() < (2*shared) ){
			UpdateHashTables( heads, middles, seq, i, shared, min );
			continue;
		}

		hash = MakeHash( seq->SequenceData(), shared );
		node = heads.Find( hash );
		if( node == NULL ){
			UpdateHashTables( heads, middles, seq, i, shared, min );
			continue;
		}

		Array<HashHit> & hits = node->value;
		for(j=0, M=hits.Size(); j<M; j++){
			HashHit & hit = hits[j];
			Sequence *rep = clusters[hit.index][0];
			if( hit.offset ) continue;
			if( clusters[hit.index].GetAbundance() < qn ) continue;

			K = ComparePrefix( seq->SequenceData(), rep->SequenceData() );
			if( (K+shared) > seq->Length() ) K = seq->Length() - shared;

			int dep = HashingDepth( seq->Length()-K, min );
			int hashlen = HashingLength( dep, min );

			hash = MakeHash( seq->SequenceData(), K, hashlen );
			node = middles[dep].Find( hash );
			if( node == NULL ) continue;

			Array<HashHit> & hits2 = node->value;
			for(k=0; k<hits2.Size(); k++){
				HashHit & hit2 = hits2[k];
				Sequence *rep2 = clusters[hit2.index][0];
				if( clusters[hit2.index].GetAbundance() < qn ) continue;
				//printf( "%s\n", seq->SequenceData().Data() + K );
				//printf( "%s\n", rep2->SequenceData().Data() + hit2.offset );
				K2 = ComparePrefix( seq->SequenceData(), K+hashlen, rep2->SequenceData(), hit2.offset+hashlen );
				if( (K + hashlen + K2) == seq->Length() ){
					int C = K < hit2.offset ? K : hit2.offset;
					int K3 = ComparePrefix( seq->SequenceData(), K-C, rep2->SequenceData(), hit2.offset-C, C );
					if( K3 != C ){
						chistat.Append( ChimericSource( i, hit.index, hit2.index ) );
						count += 1;

#if 0
						int ii;
						printf( "K = %i;  C = %i;  K3 = %i;  C-K3 = %i\n", K, C, K3, C-K3 );
						for(ii=0; ii<K; ii++){
							char ch = rep->SequenceData()[ii];
							if( ii == K-C+K3 ) ch = tolower( ch ), printf( " "  );
							printf( "%c", ch );
						}
						printf( "  " );
						for(ii=K; ii<rep->Length(); ii++) printf( "%c", rep->SequenceData()[ii] ); printf( "\n" );
						for(ii=0; ii<hit2.offset; ii++){
							char ch = rep2->SequenceData()[ii];
							if( ii == hit2.offset-C+K3 ) ch = tolower( ch ), printf( " "  );
							printf( "%c", ch );
						}
						printf( "  " );
						for(ii=hit2.offset; ii<rep2->Length(); ii++) printf( "%c", rep2->SequenceData()[ii] ); printf( "\n" );
						for(ii=0; ii<K; ii++){
							char ch = seq->SequenceData()[ii];
							if( ii == K-C+K3 ) ch = tolower( ch ), printf( " "  );
							printf( "%c", ch );
						}
						printf( "  " );
						for(ii=K; ii<seq->Length(); ii++) printf( "%c", seq->SequenceData()[ii] ); printf( "\n" );
						printf( "\n\n" );
#endif
						break;
					}
				}
			}
			if( chistat.Size() && chistat.Back().index == i ) break;
		}
		if( (i+1) % 1000 ==0 ) printf( "Checked %9i clusters, detected %9i chimeric clusters\n", i+1, chistat.Size() );
		if( chistat.Size() ==0 || chistat.Back().index != i ){
			UpdateHashTables( heads, middles, seq, i, shared, min );
		}
	}
}

const char *help =
"Options:\n"
"    -i        Input file;\n"
"    -o        Output file;\n"
"    -d        Description length (default 0, truncate at the first whitespace character)\n"
"    -m        Match length (true/false, default true);\n"
"    -f        Filter out chimeric clusters (true/false, default false);\n"
"    -s        Minimum length of common sequence shared between a chimeric read\n"
"              and each of its parents (default 30);\n"
"    -a        Abundance cutoff (default 1 without chimeric filtering, 2 with chimeric filtering);"
;

int main( int argc, char *argv[] )
{
	if( argc < 5 ){
		printf( "%s\n", help );
		return 1;
	}
	String input, output;
	bool matchLength = true;
	bool nochimeric = false;
	int abundance = -1;
	int deslen = 0;
	int shared = 30;
	int i, m;

	for(i=1; i<argc; i+=2){
		if( i+1 == argc ){
			printf( "Incomplete argument %s\n", argv[i] );
			printf( "\n%s\n", help );
			return 1;
		}
		if( strcmp( argv[i], "-i" ) == 0 ) input = argv[i+1];
		else if( strcmp( argv[i], "-o" ) == 0 ) output = argv[i+1];
		else if( strcmp( argv[i], "-a" ) == 0 ) abundance = strtol( argv[i+1], NULL, 10 );
		else if( strcmp( argv[i], "-d" ) == 0 ) deslen = strtol( argv[i+1], NULL, 10 );
		else if( strcmp( argv[i], "-m" ) == 0 ) matchLength = strcmp( argv[i+1], "true" ) ==0;
		else if( strcmp( argv[i], "-f" ) == 0 ) nochimeric = strcmp( argv[i+1], "true" ) ==0;
		else if( strcmp( argv[i], "-s" ) == 0 ){
			shared = strtol( argv[i+1], NULL, 10 );
			nochimeric = true;
			printf( "Chimeric cluster filtering is automatically enabled by \"-s\" parameter!\n" );
		}else{
			printf( "Unknown argument %s\n", argv[i] );
			printf( "\n%s\n", help );
			return 1;
		}
	}

	SequenceList seqlist;
	seqlist.ReadFastAQ( input );

	printf( "Total number of sequences: %i\n", seqlist.Count() );
	printf( "Longest: %i\n", seqlist.MaxLength() );
	printf( "Shortest: %i\n", seqlist.MinLength() );

	if( seqlist.MaxLength() != seqlist.MinLength() ){
		seqlist.SortByLength();
		printf( "Sorted by length ...\n" );
	}

	Array<SequenceCluster> clusters;
	Array<ChimericSource> chistat;
	printf( "Start clustering duplicated sequences ...\n" );
	ClusterDuplicate( seqlist, clusters, matchLength );
	printf( "Number of clusters found: %i\n", clusters.Size() );

	for(i=0, m=clusters.Size(); i<m; i++){
		clusters[i].SetAbundance( clusters[i].Size() );
	}
	if( nochimeric ){
		if( abundance < 0 ) abundance = 2;
		if( seqlist.Count() == clusters.Size() ){
			for(i=0, m=clusters.Size(); i<m; i++){
				Sequence *rep = clusters[i][0];
				String & des = rep->Description();
				int ab = 1;
				int pos = des.Find( "_abundance_" );
				if( pos ) ab = strtol( des.Data() + pos + 10, NULL, 10 );
				clusters[i].SetAbundance( ab );
			}
		}

		SortByAbundance( clusters );
		DetectChimeric( clusters, chistat, seqlist.MaxLength(), shared, abundance );
		for(i=0, m=0; i<chistat.Size(); i++){
			clusters[chistat[i].index].SetChimericParent( chistat[i].head, chistat[i].tail );
		}
		printf( "Number of chimeric clusters found: %i\n", chistat.Size() );
	}
	if( abundance < 0 ) abundance = 1;
	int above = 0;
	int below = 0;
	for(i=0, m=clusters.Size(); i<m; i++){
		if( clusters[i].GetChimericParent1() == clusters[i].GetChimericParent2() ){
			bool ab = clusters[i].GetAbundance() < abundance;
			above += ab == false;
			below += ab == true;
		}
	}
	printf( "Number of clusters with abundance above the cutoff (=%i): %i\n", abundance, above );
	printf( "Number of clusters with abundance below the cutoff (=%i): %i\n", abundance, below );
	printf( "Writing clusters to files ...\n" );
	WriteClusters( clusters, output, deslen );
	printf( "Done!\n" );
	return 0;
}
