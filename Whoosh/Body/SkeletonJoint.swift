//
//  SkeletonJoint.swift
//  BodyTracking2022
//
//  Created by Ryan Kopinsky on 6/17/22.
//

/*
 Copyright 2022 Reality School
 
 All rights reserved. No part of this source code may be reproduced
 or distributed by any means without prior written permission of the copyright owner.
 It is strictly prohibited to publish any parts of the
 source code to publicly accessible repositories or websites.
 
 You are hereby granted permission to use and/or modify
 the source code in as many apps as you want, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*/

import Foundation

struct SkeletonJoint {
    let name: String
    var position: SIMD3<Float>
}
