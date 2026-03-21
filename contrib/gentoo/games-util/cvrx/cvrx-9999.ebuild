# Copyright 2024-2026 Gentoo Authors
# Distributed under the terms of the MIT License

EAPI=8

inherit git-r3 xdg-utils

DESCRIPTION="A friend/world/avatar/prop management app extension to ChilloutVR"
HOMEPAGE="https://github.com/AstroDogeDX/CVRX"
EGIT_REPO_URI="https://github.com/AstroDogeDX/CVRX.git"

LICENSE="MIT"
SLOT="0"

RDEPEND="
	x11-libs/gtk+:3
	x11-libs/libXtst
	dev-libs/nss
	media-libs/alsa-lib
	x11-libs/libnotify
	app-accessibility/at-spi2-core
"

BDEPEND="
	net-libs/nodejs[npm]
"

# Electron downloads its own binary; network access needed during build
RESTRICT="network-sandbox"

QA_PREBUILT="
	opt/cvrx/*
"

src_prepare() {
	default

	# Remove preexisting node_modules if present
	rm -rf "${S}/node_modules" || die
}

src_compile() {
	# Ensure npm has a writable home and cache inside the build dir
	export HOME="${T}/home"
	export npm_config_cache="${T}/npm-cache"
	mkdir -p "${HOME}" "${npm_config_cache}" || die

	# Install npm dependencies
	npm ci --no-audit --no-fund || die "npm ci failed"

	# Package the app using electron-forge
	npx electron-forge package || die "electron-forge package failed"
}

src_install() {
	local instdir="/opt/cvrx"

	# Electron Forge outputs to out/<productName>-linux-x64/
	local outdir="${S}/out/CVRX-linux-x64"

	if [[ ! -d "${outdir}" ]]; then
		die "Packaged output not found at ${outdir}"
	fi

	# Install the packaged Electron app
	insinto "${instdir}"
	doins -r "${outdir}"/.

	# The main binary is named after productName in package.json
	fperms 0755 "${instdir}/CVRX"

	# Fix permissions on bundled Electron binaries and shared libraries
	local f
	for f in chrome-sandbox chrome_crashpad_handler libEGL.so libGLESv2.so \
		libvk_swiftshader.so libvulkan.so.1; do
		if [[ -f "${ED}${instdir}/${f}" ]]; then
			fperms 0755 "${instdir}/${f}"
		fi
	done

	# chrome-sandbox needs SUID for Chromium sandboxing
	if [[ -f "${ED}${instdir}/chrome-sandbox" ]]; then
		fperms 4755 "${instdir}/chrome-sandbox"
	fi

	# Create wrapper script in PATH
	dodir /usr/bin
	cat > "${ED}/usr/bin/cvrx" <<-'WRAPPER' || die
		#!/bin/sh
		exec /opt/cvrx/CVRX "$@"
	WRAPPER
	fperms 0755 /usr/bin/cvrx

	# Install desktop entry
	cat > "${T}/cvrx.desktop" <<-'DESKTOP' || die
		[Desktop Entry]
		Name=CVRX
		Comment=Friend/world/avatar/prop management for ChilloutVR
		Exec=/usr/bin/cvrx %U
		Icon=cvrx
		Type=Application
		Categories=Game;Utility;
		StartupWMClass=CVRX
	DESKTOP
	insinto /usr/share/applications
	doins "${T}/cvrx.desktop"

	# Install icon
	insinto /usr/share/icons/hicolor/256x256/apps
	newins "${S}/icon/cvrx-logo.png" cvrx.png

	dodoc README.md
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
