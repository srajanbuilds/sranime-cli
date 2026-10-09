class SranimeCli < Formula
  desc "Cli tool to browse and play anime"
  homepage "https://github.com/srajanbuilds/sranime-cli"
  url "https://github.com/srajanbuilds/sranime-cli/archive/refs/tags/v5.3.0.tar.gz"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  license "GPL-3.0"
  head "https://github.com/srajanbuilds/sranime-cli.git", branch: "main"

  depends_on "curl"
  depends_on "ffmpeg"
  depends_on "fzf"
  depends_on "grep"
  depends_on "yt-dlp"
  depends_on "aria2" => :optional
  depends_on "mpv" => :recommended

  def install
    bin.install "sranime-cli"
    man1.install "sranime-cli.1"
    (lib/"sranime-cli").install Dir["lib/sranime-cli/*"]
    bash_completion.install "_sranime-cli-bash" => "sranime-cli"
    zsh_completion.install "_sranime-cli-zsh" => "_sranime-cli"
    fish_completion.install "completions/sranime-cli.fish" => "sranime-cli.fish"
  end

  def caveats
    <<~EOS
      On macOS you can install IINA player instead of mpv for better experience:
        brew install --cask iina

      Run 'sranime-cli --doctor' to verify your setup.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/sranime-cli --version")
    assert_match "sranime-cli", shell_output("#{bin}/sranime-cli --help")
  end
end
