# RPi4 Arm64 Kernel Headers Builder

This tool provides users with an automated procedure written in Bash Script to build kernel headers for their Raspberry Pi 4 **Arm64** models and it works only on Raspberry Pi OS and Raspbian 64 bit. 


## Installation of Master Branch & Building Kernel Headers

1. Update your kernel using the command ``sudo BRANCH=master rpi-update``, once finished reboot using ``sudo reboot now``;
2. Clone this repository in a directory of your choice (home directory is recommended), enter in the cloned repository directory and run the command ``./rpi4-arm64-kernel-headers-builder-master-branch.sh``, once finished reboot using ``sudo reboot now``.

## Installation of Next Branch & Building Kernel Headers

1. Update your kernel using the command ``sudo BRANCH=next rpi-update``, once finished reboot using ``sudo reboot now``;
2. Clone this repository in a directory of your choice (home directory is recommended), enter in the cloned repository directory and run the command ``./rpi4-arm64-kernel-headers-builder-next-branch.sh``, once finished reboot using ``sudo reboot now``.

## License

### MIT LICENSE

Copyright (c) 2021 Mattia Pintus

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.