#include	"plan9.h"
#include	<bio.h>

int
Bfildes(Biobuf *bp)
{

	return bp->fid;
}
