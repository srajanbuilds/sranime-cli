# Maintainer: Srajan <https://github.com/srajanbuilds>
pkgname=sranime-cli
pkgver=6.0.0
pkgrel=1
pkgdesc="High-performance POSIX CLI to browse, stream, download, and track anime"
arch=('any')
url="https://github.com/srajanbuilds/sranime-cli"
license=('GPL3')
depends=('curl' 'fzf' 'grep' 'sed')
optdepends=(
    'mpv: Default and recommended video player'
    'aria2: Multi-connection accelerated chunk downloads'
    'yt-dlp: HLS / m3u8 stream extraction fallback'
    'ffmpeg: Stream remuxing and container conversions'
    'chafa: Terminal cover art preview rendering'
    'ani-skip: Opening/ending intro skipping'
    'syncplay: Synchronized watch parties with friends'
    'libnotify: Desktop notifications on Linux'
)
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

package() {
    cd "$pkgname-$pkgver"
    make DESTDIR="$pkgdir" PREFIX="/usr" install
}
