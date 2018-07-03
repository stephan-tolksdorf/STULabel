// Copyright 2017–2018 Stephan Tolksdorf

#import "SnapshotTestCase.h"

CF_EXTERN_C_BEGIN

CGAffineTransform CGContextGetBaseCTM(CGContextRef c);
void CGContextSetBaseCTM(CGContextRef c, CGAffineTransform ctm);

CF_EXTERN_C_END
