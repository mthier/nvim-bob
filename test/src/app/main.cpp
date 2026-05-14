#include <iostream>
#include "lib_a.h"
#include "lib_b.h"

int main() {
    std::cout << lib_a::greet() << "\n";
    std::cout << lib_b::greet() << "\n";
    return 0;
}
