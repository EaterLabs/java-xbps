mkdir -p build/eaters-java-home/etc/profile.d;
cp java-profile.sh build/eaters-java-home/etc/profile.d/999_java-home.sh
chmod +x build/eaters-java-home/etc/profile.d/999_java-home.sh
PKGCHROOT="$(realpath "build/eaters-java-home")";
cd binpkgs;
xbps-create \
  -A "noarch" \
  -B "Eater's binary Java builder" \
  -m "eater <=@eater.me>" \
  -t "java eater" \
  -n "eaters-java-home-1.0_1" \
  -s "Binary java build of ${IMPLEMENTOR}" \
  "${PKGCHROOT}";

rm -rf "${PKGCHROOT}";
