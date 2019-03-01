set -e
set -x
cat zepto.min.js smoothie.js sprintf.js gauge.min.js > utils.js
rm -f utils.js.gz
gzip --keep utils.js
