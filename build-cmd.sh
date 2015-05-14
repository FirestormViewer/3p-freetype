#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

FREETYPELIB_SOURCE_DIR="freetype-2.3.9"

if [ -z "$AUTOBUILD" ] ; then
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

top="$(pwd)"
stage="$(pwd)/stage"

[ -f "$stage"/packages/include/zlib/zlib.h ] || fail "You haven't installed packages yet."

# extract Freetype version into VERSION.txt
FREETYPE_INCLUDE_DIR="${top}/${FREETYPELIB_SOURCE_DIR}/include/freetype"
if [ "$OSTYPE" = "cygwin" ] ; then
  FREETYPE_INCLUDE_DIR="$(cygpath -m $FREETYPE_INCLUDE_DIR)"
fi
major_version=$(perl -ne 's/#\s*define\s+FREETYPE_MAJOR\s+([\d]+)/$1/ && print' "${FREETYPE_INCLUDE_DIR}/freetype.h")
minor_version=$(perl -ne 's/#\s*define\s+FREETYPE_MINOR\s+([\d]+)/$1/ && print' "${FREETYPE_INCLUDE_DIR}/freetype.h")
patch_version=$(perl -ne 's/#\s*define\s+FREETYPE_PATCH\s+([\d]+)/$1/ && print' "${FREETYPE_INCLUDE_DIR}/freetype.h")
version="${major_version}.${minor_version}.${patch_version}"
build=${AUTOBUILD_BUILD_ID:=0}
echo "${version}.${build}" > "${stage}/VERSION.tmp"
tr -d "\r\n" < "${stage}/VERSION.tmp" > "${stage}/VERSION.txt"
rm "${stage}/VERSION.tmp"

pushd "$FREETYPELIB_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars

			if [ "${ND_AUTOBUILD_ARCH}" == "x64" ]
			then
				build_sln "builds/win32/vc2013/freetype.sln" "LIB Debug|x64"
				build_sln "builds/win32/vc2013/freetype.sln" "LIB Release|x64"
			else
				build_sln "builds/win32/vc2013/freetype.sln" "LIB Debug|Win32"
				build_sln "builds/win32/vc2013/freetype.sln" "LIB Release|Win32"
			fi

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp -a "objs/win32/vc2013/freetype239_D.lib" "$stage/lib/debug/freetype.lib"
            cp -a "objs/win32/vc2013/freetype239.lib" "$stage/lib/release/freetype.lib"

            mkdir -p "$stage/include/freetype2/"
            cp -a include/ft2build.h "$stage/include/freetype2/"
            cp -a include/freetype "$stage/include/freetype2/"
        ;;

        "darwin")
            # Darwin build environment at Linden is also pre-polluted like Linux
            # and that affects colladadom builds.  Here are some of the env vars
            # to look out for:
            #
            # AUTOBUILD             GROUPS              LD_LIBRARY_PATH         SIGN
            # arch                  branch              build_*                 changeset
            # helper                here                prefix                  release
            # repo                  root                run_tests               suffix

            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk/

            opts32="${TARGET_OPTS:--arch i386 -iwithsysroot $sdk -mmacosx-version-min=10.7}"
            opts64="${TARGET_OPTS:--arch x86_64 -iwithsysroot $sdk -mmacosx-version-min=10.7}"

            # Debug first
            CFLAGS="$opts32 -gdwarf-2 -O0" \
                CXXFLAGS="$opts32 -gdwarf-2 -O0" \
                CPPFLAGS="-I$stage/packages/include/zlib" \
                LDFLAGS="$opts32 -Wl,-headerpad_max_install_names -L$stage/packages/lib/debug -Wl,-unexported_symbols_list,$stage/packages/lib/debug/libz_darwin.exp" \
                ./configure --with-pic \
                --prefix="${stage}32" --libdir="${stage}32"/lib/debug/
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # make test
                echo "No tests"
            fi

            install_name_tool -id "@executable_path/../Resources/libfreetype.6.dylib" "${stage}32"/lib/debug/libfreetype.6.dylib

            make distclean

            # Debug first
            CFLAGS="$opts64 -gdwarf-2 -O0" \
                CXXFLAGS="$opts64 -gdwarf-2 -O0" \
                CPPFLAGS="-I$stage/packages/include/zlib" \
                LDFLAGS="$opts64 -Wl,-headerpad_max_install_names -L$stage/packages/lib/debug -Wl,-unexported_symbols_list,$stage/packages/lib/debug/libz_darwin.exp" \
                ./configure --with-pic \
                --prefix="${stage}64" --libdir="${stage}64"/lib/debug/
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # make test
                echo "No tests"
            fi

            install_name_tool -id "@executable_path/../Resources/libfreetype.6.dylib" "${stage}64"/lib/debug/libfreetype.6.dylib

            make distclean

            # Release last
            CFLAGS="$opts32 -gdwarf-2 -O2" \
                CXXFLAGS="$opts32 -gdwarf-2 -O2" \
                CPPFLAGS="-I$stage/packages/include/zlib" \
                LDFLAGS="$opts32 -Wl,-headerpad_max_install_names -L$stage/packages/lib/release -Wl,-unexported_symbols_list,$stage/packages/lib/release/libz_darwin.exp" \
                ./configure --with-pic \
                --prefix="${stage}32" --libdir="${stage}32"/lib/release/
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # make test
                echo "No tests"
            fi

            install_name_tool -id "@executable_path/../Resources/libfreetype.6.dylib" "${stage}32"/lib/release/libfreetype.6.dylib

            make distclean

            # Release last
            CFLAGS="$opts64 -gdwarf-2 -O2" \
                CXXFLAGS="$opts64 -gdwarf-2 -O2" \
                CPPFLAGS="-I$stage/packages/include/zlib" \
                LDFLAGS="$opts64 -Wl,-headerpad_max_install_names -L$stage/packages/lib/release -Wl,-unexported_symbols_list,$stage/packages/lib/release/libz_darwin.exp" \
                ./configure --with-pic \
                --prefix="${stage}64" --libdir="${stage}64"/lib/release/
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # make test
                echo "No tests"
            fi

            install_name_tool -id "@executable_path/../Resources/libfreetype.6.dylib" "${stage}64"/lib/release/libfreetype.6.dylib

            make distclean

	    rm -rf $stage/{bin,include,lib,share}
	    cp -aR ${stage}32/* $stage
	    pushd $stage/lib
	      find . -type f -name \*.dylib -print | xargs -I % lipo ${stage}32/lib/% ${stage}64/lib/% -create -output %
	      find . -type f -name \*.a -print | xargs -I % lipo ${stage}32/lib/% ${stage}64/lib/% -create -output %
	    popd
        ;;

        "linux")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.6 if available.
            if [ -x /usr/bin/gcc-4.6 -a -x /usr/bin/g++-4.6 ]; then
                export CC=/usr/bin/gcc-4.6
                export CXX=/usr/bin/g++-4.6
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Debug first
            CFLAGS="$opts -g -O0" \
                CXXFLAGS="$opts -g -O0" \
                CPPFLAGS="-I$stage/packages/include/zlib" \
                LDFLAGS="$opts -L$stage/packages/lib/debug -Wl,--exclude-libs,libz" \
                ./configure --with-pic \
                --prefix="$stage" --libdir="$stage"/lib/debug/
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # make test
                echo "No tests"
            fi

            make distclean

            # Release last
            CFLAGS="$opts -g -O2" \
                CXXFLAGS="$opts -g -O2" \
                CPPFLAGS="-I$stage/packages/include/zlib" \
                LDFLAGS="$opts -L$stage/packages/lib/release -Wl,--exclude-libs,libz" \
                ./configure --with-pic \
                --prefix="$stage" --libdir="$stage"/lib/release/
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # make test
                echo "No tests"
            fi

            make distclean
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp docs/LICENSE.TXT "$stage/LICENSES/freetype.txt"
popd

mkdir -p "$stage"/docs/freetype/
cp -a README.Linden "$stage"/docs/freetype/

pass

