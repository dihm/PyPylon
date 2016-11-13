from pypylon.cython.factory import Factory
from pypylon.cython.version import PylonVersion

# With earlier versions of python that don't support PEP 435 enums (discovered on an Ubuntu 14.04 with stock python 2.7.6) cython
# seems to silently drop the EGrabStrategy enum. declared with cpdef directive in factory.pyx, so have to define it manually.
GrabStrategy_OneByOne           = 0
GrabStrategy_LatestImageOnly    = 1
GrabStrategy_LatestImages       = 2
GrabStrategy_UpcomingImage      = 3

try:
    # If running on python version where EGrabStrategy is sucessfully exported, sanity check that values match our manual
    # definitions
    from pypylon.cython.factory import EGrabStrategy

    assert GrabStrategy_OneByOne           == EGrabStrategy.GrabStrategy_OneByOne
    assert GrabStrategy_LatestImageOnly    == EGrabStrategy.GrabStrategy_LatestImageOnly
    assert GrabStrategy_LatestImages       == EGrabStrategy.GrabStrategy_LatestImages
    assert GrabStrategy_UpcomingImage      == EGrabStrategy.GrabStrategy_UpcomingImage

except ImportError:
    pass


factory = Factory()
pylon_version = PylonVersion()
