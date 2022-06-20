import os.path
from dask import delayed


@delayed
def tree(dir):
    result = []
    for path, dirs, files in os.walk(dir):
        result = result + [path]
        result = result + [os.path.join(path, file) for file in files]
    return result