Name:      bluetooth-firmware-bcm
Summary:    firmware and tools for bluetooth
Version:    0.1.3
Release:    1
Group:      Hardware Support/Handset
License:    Apache
# NOTE: Source name does not match package name.  This should be
# resolved in the future, by I don't have that power. - Ryan Ware
Source0:    %{name}-%{version}.tar.gz

BuildRequires:  pkgconfig(vconf)
BuildRequires:  cmake

%description
 firmware and tools for bluetooth

%package exynos3250
Summary:    bcm firmware and tools for exynos3250
Group:      TO_BE/FILLED

%description exynos3250
bcm firmware and tools for exynos3250

%prep
%setup -q

%build
cmake ./ -DCMAKE_INSTALL_PREFIX=%{_prefix} -DPLUGIN_INSTALL_PREFIX=%{_prefix}
make %{?jobs:-j%jobs}

%install
rm -rf %{buildroot}

%make_install

mkdir -p %{buildroot}/usr/share/license
cp LICENSE.APLv2 %{buildroot}/usr/share/license/%{name}
cat %{_builddir}/%{name}-%{version}/LICENSE.Broadcom >> %{buildroot}/usr/share/license/%{name}

%files
%defattr(-,root,root,-)
#%{_bindir}/bcmtool_4330b1
%exclude %{_bindir}/bcmtool_4343w
%{_bindir}/bcmtool_4358a1
%{_bindir}/setbd
#%{_prefix}/etc/bluetooth/BT_FW_BCM4330B1_002.001.003.0221.0265.hcd
%{_prefix}/etc/bluetooth/BT_FW_BCM4358A1_001.002.005.0032.0066.hcd
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-dev-end.sh
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-dev-start.sh
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-set-addr.sh

%files exynos3250
%defattr(-,root,root,-)
%{_bindir}/bcmtool_4343w
%{_bindir}/setbd
%{_prefix}/etc/bluetooth/BCM4343A1_001.002.009.0035.0096_ORC_Orbis_WC1-S.hcd
%{_prefix}/etc/bluetooth/BCM4343A1_001.002.009.0022.0050_Murata_Type-1FR.hcd
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-dev-end.sh
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-dev-start-exynos3250.sh
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-set-addr.sh
/usr/share/license/%{name}
