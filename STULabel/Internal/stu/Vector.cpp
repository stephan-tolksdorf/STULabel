// Copyright 2017 Stephan Tolksdorf

#include "stu/Vector.hpp"

namespace stu {

template struct detail::VectorBase<Malloc, false>;
template struct detail::VectorBase<Malloc, true>;

} // namespace stu
