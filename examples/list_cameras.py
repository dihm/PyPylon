from __future__ import absolute_import, print_function, division

import pypylon
import matplotlib.pyplot as plt
import numpy as np

print('Build against pylon library version:', pypylon.pylon_version.version)

available_cameras = pypylon.factory.find_devices()
print('Available cameras are', available_cameras)

# Grep the last one and create a camera for it
cam = pypylon.factory.create_device(available_cameras[-1])

# We can still get information of the camera back
print('Camera info of camera object:', cam.device_info)

# Open camera and grep some images
cam.open()

# Hard code exposure time (in us)
cam.properties['ExposureTime'] = 10000.0
cam.properties['PixelFormat'] = 'Mono12'
print(cam.properties['PixelSize'])

# Go to full available speed
# cam.properties['DeviceLinkThroughputLimitMode'] = 'Off'

for key in cam.properties.keys():
    try:
        value = cam.properties[key]
    except IOError:
        value = '<NOT READABLE>'

    print('{0} ({1}):\t{2}'.format(key, cam.properties.get_description(key), value))

plt.figure()
for image in cam.grab_images(1):
    print(image.shape)
    plt.imshow(image)
    plt.show()
