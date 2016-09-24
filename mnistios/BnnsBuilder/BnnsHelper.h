#pragma once

#import <Accelerate/Accelerate.h>


BNNSFilterParameters defaultFilterParameters()
{
    static BNNSFilterParameters params = {};
    
    return params;
}
