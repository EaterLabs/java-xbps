#!/usr/bin/env bash
set -e

TAR="${1}";
MOD="${2}";
HINTS="${3}";
echo "Searching release info..."
RELEASE_INFO="$(tar --wildcards -xOf "${TAR}" '*/release' | tr '$' '_' | tr '`' '_' | grep '^[A-Z_0-9]\+=')"
eval "${RELEASE_INFO}"

if [[ ! -z "${HINTS}" ]]; then
  eval "${HINTS}";
fi

if [[ -z "${JAVA_VERSION}" ]]; then
  echo "Invalid file";
  exit 1;
fi

if [[ "${OS_NAME}" != "Linux" ]]; then
  echo "Build not for Linux";
  exit 1;
fi

if [[ "${OS_ARCH}" = "amd64" ]]; then
  OS_ARCH="x86_64"
fi

if [[ "${OS_ARCH}" != "x86_64" ]]; then
  echo "Script only supports 64-bit java distributions";
  exit 1;
fi

case "${IMPLEMENTOR}" in
  (Oracle*|oracle*)
    if [[ -z "${BUILD_TYPE}" ]]; then
      NAME="openjdk";
    else
      NAME="oraclejdk";
    fi
    ;;
  (Adopt*)
    NAME="openjdk";
    EXTRA="adoptopenjdk"
    ;;
esac

if [[ -z "${NAME}" ]]; then
  echo "Can't find name";
  exit 1;
fi

NAME+="${JAVA_VERSION}";

if [[ ! -z "${EXTRA}" ]]; then
  NAME+="-${EXTRA}";
fi

if grep -iq "openj9" <<<"${SOURCE}"; then
  NAME+="-openj9";
fi

if [[ ! -z "${MOD}" ]]; then
  NAME+="-${MOD}"
fi

echo "Extracting with name: ${NAME}";
JVMDIR="/usr/lib/jvm/${NAME}"
echo "> jdk dir: ${JVMDIR}";
BUILDJVMDIR="build/${NAME}/${JVMDIR}";

mkdir -p "${BUILDJVMDIR}";
BUILDJVMDIR="$(realpath "${BUILDJVMDIR}")"
tar -C "${BUILDJVMDIR}" -m --owner="$(id -nu)" --group="$(id -ng)" -p -f "${TAR}" --strip-components=1 -x;

echo "Creating alternatives string";
JRE_IS_JDK="1"
if [[ -d "${BUILDJVMDIR}/jre/bin" ]]; then
  JRE_IS_JDK=0

  while read file; do
    ALTS+="java:/usr/bin/${file}:${JVMDIR}/jre/bin/${file} ";
  done < <(find "${BUILDJVMDIR}/jre/bin" -maxdepth 1 -executable -printf '%f\n')
fi

while read file; do
  if [[ "${JRE_IS_JDK}" = "1" ]]; then
    ALTS+="java:/usr/bin/${file}:${JVMDIR}/bin/${file} ";
  fi

  ALTS+="jdk:/usr/bin/${file}:${JVMDIR}/bin/${file} ";
done < <(find "${BUILDJVMDIR}/bin" -maxdepth 1 -executable -printf '%f\n')

ALTS+="java-home:/usr/lib/jvm/home:${JVMDIR}"

echo "Creating shlib requires";

LIBS="$(find "${BUILDJVMDIR}" -regex '.*/\(bin/[^\/]+\|lib/.*\.so\)' -exec ldd {} \; 2>/dev/null | \
 grep -Po '\S*(?= =>.*$)|^\s*\K\S*' | \
 awk '!z[$0]{z[$0]=1;print}')"


SHLIBS="$(while read lib; do
  # Check if lib is provided by ourselves.
  if find "${BUILDJVMDIR}" -name "${lib}" -printf "ok" -quit | grep -q ok; then
    continue;
  fi

  if grep -q linux <<< "${lib}"; then
    continue
  fi

  echo "${lib}" | grep -o '[A-Za-z0-9\._-]+$'
done <<<"${LIBS}" | awk '!z[$0]{z[$0]=1;printf$0" "}')"

PKGCHROOT="$(realpath "build/${NAME}")"
echo "Creating package...";

cd binpkgs;
xbps-create \
  -A "${OS_ARCH}" \
  -B "Eater's binary Java builder" \
  -D "eaters-java-home>=1.0" \
  -m "eater <=@eater.me>" \
  -P "java-environment-${JAVA_VERSION}_1" \
  -t "java eater" \
  -n "${NAME}-${JAVA_VERSION_DATE//-/.}_1" \
  -s "Binary java build of ${IMPLEMENTOR}" \
  --shlib-requires "${SHLIBS}" \
  --alternatives "${ALTS}" \
  "${PKGCHROOT}" >/dev/null;

rm -rf "${PKGCHROOT}"
