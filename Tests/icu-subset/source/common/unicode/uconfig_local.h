// We only need this ICU subset for *testing* the code point properties and the grapheme cluster
// iteration. We will get rid of this library once iOS updates its system ICU.

#define U_NO_DEFAULT_INCLUDE_UTF_HEADERS 1

#define U_ENABLE_DYLOAD 0

#define U_CHECK_DYLOAD 0

#define UCONFIG_NO_FILE_IO 1

#define UCONFIG_NO_CONVERSION 1

#define UCONFIG_NO_NORMALIZATION 1

#define UCONFIG_NO_IDNA 1

#define UCONFIG_NO_COLLATION 1

#define UCONFIG_NO_FORMATTING 1

#define UCONFIG_NO_TRANSLITERATION 1

#define UCONFIG_NO_REGULAR_EXPRESSIONS 1

#define UCONFIG_NO_SERVICE 1

#define UCONFIG_NO_FILTERED_BREAK_ITERATION 1

