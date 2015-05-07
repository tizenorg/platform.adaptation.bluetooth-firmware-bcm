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


%prep
%setup -q

%build
cmake ./ -DCMAKE_INSTALL_PREFIX=%{_prefix} -DPLUGIN_INSTALL_PREFIX=%{_prefix}
make %{?jobs:-j%jobs}

%install
rm -rf %{buildroot}
%make_install


%files
%defattr(-,root,root,-)
#%{_bindir}/bcmtool_4330b1
%{_bindir}/bcmtool_4358a1
%{_bindir}/setbd
#%{_prefix}/etc/bluetooth/BT_FW_BCM4330B1_002.001.003.0221.0265.hcd
%{_prefix}/etc/bluetooth/BT_FW_BCM4358A1_001.002.005.0032.0066.hcd
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-dev-end.sh
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-dev-start.sh
%attr(755,-,-) %{_prefix}/etc/bluetooth/bt-set-addr.sh
