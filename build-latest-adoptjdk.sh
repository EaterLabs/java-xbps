for jdk in openjdk8 openjdk10 openjdk11 openjdk12; do
  JSON="$(curl "https://api.adoptopenjdk.net/v2/latestAssets/releases/${jdk}?os=linux&arch=x64&release=latest&type=jdk")"

  while read heap_size name link impl; do
    mod=""
    if [[ "${heap_size}" = "large" ]]; then
      mod="large-heapsize"
    fi

    if grep -Fq "$link" known_binaries; then
      continue;
    fi

    HINTS="""
IMPLEMENTOR=AdoptOpenJdk
SOURCE=$impl
    """

    wget -nc -O "binaries/${name}" "$link";
    bash ./build-xbps.sh "$(realpath binaries/${name})" "${mod}" "${HINTS}";
    echo "${link}" >> known_binaries
  done < <(jq -r 'map("\(.heap_size) \(.binary_name) \(.binary_link) \(.openjdk_impl)")[]' <<< "${JSON}")
done
