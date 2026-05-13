#include "lib_b.h"
#include "lib_a.h"

namespace lib_b {

const std::string greet() {
    return "Hello from lib_b and " + lib_a::greet();
}

}  // namespace lib_b
