#include <maglev.h>

struct SharedData {
        int ownFwmark;
        int fwOffset;
        struct MagData magd;
};

extern char const* const defaultLbShm;
extern char const* const defaultTargetShm;

