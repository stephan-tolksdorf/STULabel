// Copyright 2017–2018 Stephan Tolksdorf

#import "STUTextAttributes-Internal.hpp"

#import "Internal/InputClamping.hpp"
#import "Internal/NSCoderUtils.hpp"
#import "Internal/Once.hpp"

using namespace stu;
using namespace stu_label;

STU_EXPORT
const NSAttributedStringKey STUHyphenationLocaleIdentifierAttributeName
                              = @"STUHyphenationLocaleIdentifier";

