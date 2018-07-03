// Copyright 2017–2018 Stephan Tolksdorf

#import "HashSet.hpp"

namespace stu_label {

template class UIntHashSet<UInt16, Malloc>;
template class UIntHashSet<UInt16, ThreadLocalAllocatorRef>;

}
