//
//  swapBandR.metal
//  jscamera
//
//  Created by Yves Delacrétaz on 01.07.21.
//
// ref: https://medium.com/@shu223/core-image-filters-with-metal-71afd6377f4
#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h> // includes CIKernelMetalLib.h

extern "C" {
    namespace coreimage {

        float4 swapRedAndBlueAmount(sample_t s) {
            return s.bgra;
        }

    }
    
}

