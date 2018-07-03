// Copyright 2017 Stephan Tolksdorf

#include "stu/ArenaAllocator.hpp"

namespace stu {

template struct detail::VectorBase<ArenaAllocator<Malloc>, false>;

// template class ArenaAllocator<Malloc>; // clang bug

} // namespace stu
