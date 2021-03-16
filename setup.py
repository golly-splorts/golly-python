from setuptools import setup, find_packages, Extension
import glob
import os
from os import path

try:
    from Cython.Build import cythonize
except ImportError:
    cythonize = None

# https://github.com/FedericoStra/cython-package-example/blob/master/setup.py
# https://cython.readthedocs.io/en/latest/src/userguide/source_files_and_compilation.html#distributing-cython-modules
def no_cythonize(extensions, **_ignore):
    for extension in extensions:
        sources = []
        for sfile in extension.sources:
            path, ext = os.path.splitext(sfile)
            if ext in (".pyx", ".py"):
                if extension.language == "c++":
                    ext = ".cpp"
                else:
                    ext = ".c"
                sfile = path + ext
            sources.append(sfile)
        extension.sources[:] = sources
    return extensions


extensions = [
    Extension("life", ["golly_python/life.pyx"]),
]

CYTHONIZE = bool(int(os.getenv("CYTHONIZE", 0))) and cythonize is not None

if CYTHONIZE:
    compiler_directives = {"language_level": 3, "embedsignature": True}
    extensions = cythonize(extensions, compiler_directives=compiler_directives)
else:
    extensions = no_cythonize(extensions)

with open('requirements.txt') as f:
    required = [x for x in f.read().splitlines() if not x.startswith("#")]

with open('requirements-dev.txt') as f:
    required_dev = [x for x in f.read().splitlines() if not x.startswith("#")]

# read the contents of your README file
this_directory = path.abspath(path.dirname(__file__))
with open(path.join(this_directory, 'Readme.md'), encoding='utf-8') as f:
    long_description = f.read()

# Note: the _program variable is set in __init__.py.
from golly_python import __version__

setup(
    name='golly-python',
    version=__version__,
    packages=['golly_python'],
    ext_modules=extensions,
    description='golly-python is a package for running Game of Life simulations for Golly',
    url='https://golly.life',
    author='Ch4zm of Hellmouth',
    author_email='ch4zm.of.hellmouth@gmail.com',
    license='MIT',
    install_requires=required,
    tests_require=required_dev,
    keywords=[],
    zip_safe=False,
    long_description=long_description,
    long_description_content_type='text/markdown'
)
