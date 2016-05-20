/*
 * setbd.c
 *
 * Copyright (c) 2000 - 2011 Samsung Electronics Co., Ltd. All rights reserved
 *
 * Contact:  Hocheol Seo <hocheol.seo@samsung.com>
 *           GirishAshok Joshi <girish.joshi@samsung.com>
 *           DoHyun Pyun <dh79.pyun@samsung.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <vconf.h>
#include <glib.h>

#ifdef __TI_PATCH__
#define BT_CHIP_TI
#else
#ifdef __BROADCOM_PATCH__
#define BT_CHIP_BROADCOM
#else
#define BT_CHIP_CSR
#endif
#endif

#ifdef DEBUG_EN
#define APP_DBG(format, args...)	printf("%s(), line[%d]: " format, __FUNCTION__, __LINE__, ##args)
#define APP_DEBUG(format, args...)	printf(format, ##args)
#else
#define APP_DBG(format, args...)
#define APP_DEBUG(format, args...)
#endif

#define	BD_ADDR_FILE	"/opt/etc/.bd_addr"
#define	PSKEY_TEMP_FILE	"/opt/etc/.bluetooth.psr"
#define PSR_FILE	"/opt/etc/bluetooth/bluetooth.psr"

#define	BD_ADDR_LEN	14
#define BD_PREFIX	"0002\n"

#define PSKEY_LEN	27
#define PSKEY_BDADDR_PREFIX	"&0001 = 0012 "

#define READ_BD_FILE_MAX	300

static int success_make_bt_address_from_imei=-1;
static GMainLoop * loop;
const char *DEFAULT_IMEI="004999010640000";
static gboolean is_default_imei=FALSE;

#if defined(BT_CHIP_CSR) || defined(BT_CHIP_BROADCOM)
int addremoveBD(char* path, char* pskey){
	FILE *fd, *new;
	int ret;
	char cmp[READ_BD_FILE_MAX];
	char *result;

	fd = fopen(path, "r");
	if(NULL == fd){
		APP_DBG("Error open psr file\r\n");
		return -21;
	}

	new = fopen(PSKEY_TEMP_FILE, "w");
	if(NULL == new){
		APP_DBG("Error creat temp file\r\n");
		fclose(fd);
		return -22;
	}

	ret = fputs(pskey,new);
	APP_DBG("fputs ret: %d", ret);

	while(1){
		result = fgets(cmp, READ_BD_FILE_MAX, fd);

		APP_DBG("PSR : [%s]\r\n", cmp);

		if((NULL != result) && (0 == strncmp(cmp, "&0001", 5))){
			APP_DBG("Find BD address set script\r\n");
			continue;
		}

		if(NULL == result){
			APP_DBG("EOF reaches\r\n");
			fclose(fd);
			fclose(new);
			return 1;
		}

		ret = fputs(cmp,new);
		APP_DBG("fputs ret: %d", ret);
	}

	return 0;
}
void makeRandomBD(unsigned char* buf){
	int ran;
	int i;
	unsigned int seed;
	memcpy(buf, BD_PREFIX, 5);
	seed = time(NULL);
	for(i=5;i<14;i++){
		if(7==i){
			buf[i]='\n';
			continue;
		}
		ran = rand_r(&seed)%16;
		if(10>ran)
			ran+=0x30;
		else
			ran+=0x57;
		buf[i]=ran;
	}
	APP_DEBUG("Random number is\r\n");
	for(i=0;i<BD_ADDR_LEN;i++){
		APP_DEBUG("%c",buf[i]);
	}
	APP_DEBUG("\r\n");
}
#endif

#ifdef BT_CHIP_TI
int readBDaddrTI(void){
	int i, cnt_lap=0, cnt_uap=0, cnt_nap=0;
	int dev_id, fd, filedesc;
	BD_ADDR_T bdaddr;
	char address[18];
	char nap[4], uap[2], lap[6];
       int ret = 0;
	dev_id=hci_get_route(NULL);
	if(dev_id<0){
		APP_DBG("Bluetooth device not available!!!\r\n");
		return -1;
	}
	fd=hci_open_dev(dev_id);
	if(fd<0){
		APP_DBG("HCI open fail!!!\r\n");
		return -2;
	}

	if(0>hci_read_bd_addr(fd, &bdaddr, 1000)){
		APP_DBG("Read BD ADDR failed!!!\r\n");
		return -3;
	}
	hci_close_dev(fd);

	ba2str(&bdaddr, address);
	for(i=0;i<17;i++){
		if(':' == address[i])
			continue;

		if(5>i)
			nap[cnt_nap++] = address[i];
		else if(8>i)
			uap[cnt_uap++] = address[i];
		else
			lap[cnt_lap++] = address[i];
	}

	APP_DBG("BT address [%s], nap[%c%c%c%c], uap[%c%c], lap[%c%c%c%c%c%c]\r\n",\
	 address, nap[0], nap[1], nap[2], nap[3]\
	, uap[0],uap[1]\
	,lap[0], lap[1],lap[2],lap[3],lap[4],lap[5]);


	filedesc=open(BD_ADDR_FILE, O_RDWR | O_CREAT | O_TRUNC | O_SYNC, 0644);
	if(0>filedesc){
		APP_DBG("File creation fail!!!\r\n");
		return -4;
	}
	ret = write(filedesc, nap, 4);
	ret = write(filedesc, "\n", 1);
	ret = write(filedesc, uap, 2);
	ret = write(filedesc, "\n", 1);
	ret = write(filedesc, lap, 6);
	ret = write(filedesc, "\n", 1);
	close(filedesc);

	return 0;
}
#endif

int make_bt_address(gboolean overwrite_bt_address)
{
#if defined(BT_CHIP_CSR) || defined(BT_CHIP_BROADCOM)

	int fd;
	unsigned char txt[BD_ADDR_LEN];
	unsigned char nap[4+1], uap[2+1], lap[6+1];
#if defined(BT_CHIP_CSR)
	int i;
	char pskey[PSKEY_LEN+3];
#endif
	int ret;

	fd=open(BD_ADDR_FILE, O_RDONLY | O_SYNC);

	if(fd<0 || overwrite_bt_address==TRUE){
		if(fd<0)
			APP_DEBUG("File not exist\n");
		else
			close(fd);

		if(overwrite_bt_address)
		{
			APP_DEBUG("Overwrite BT address\n");
		}

		fd=open(BD_ADDR_FILE, O_RDWR | O_CREAT | O_TRUNC | O_SYNC, 0644);

		if (fd <0)
		{
			APP_DEBUG("Can't open address file\n");
			return 0;
		}

		makeRandomBD(txt);

		ret = write(fd, txt, BD_ADDR_LEN);
		lseek(fd, 0, SEEK_SET);
	}else{
		APP_DEBUG("%s is already existed\n",BD_ADDR_FILE);
		success_make_bt_address_from_imei=0;
	}

	ret = read(fd, nap, 5);
	ret = read(fd, uap, 3);
	ret = read(fd, lap, 7);
	close(fd);

#if defined(BT_CHIP_CSR)
	APP_DEBUG("nap[");
	for(i=0;i<4;i++)
		APP_DEBUG("%c",nap[i]);
	APP_DEBUG("]\r\n");

	APP_DEBUG("uap[");
	for(i=0;i<2;i++)
		APP_DEBUG("%c",uap[i]);
	APP_DEBUG("]\r\n");

	APP_DEBUG("lap[");
	for(i=0;i<6;i++)
		APP_DEBUG("%c",lap[i]);
	APP_DEBUG("]\r\n");

	sprintf(pskey, "&0001 = 0012 %c%c%c%c %c%c%c%c %c%c%c%c\r\n",\
	 lap[0], lap[1], lap[2], lap[3], lap[4], lap[5],\
	 uap[0], uap[1],\
	 nap[0], nap[1], nap[2], nap[3]);

	APP_DEBUG("BD PSKEY [");
	for(i=0;i<PSKEY_LEN;i++)
		APP_DEBUG("%c", pskey[i]);
	APP_DEBUG("]\r\n");

	ret = addremoveBD(PSR_FILE, pskey);
#endif
	return ret;
#elif defined(BT_CHIP_TI)
	int fd;
	int ret;

	fd=open(BD_ADDR_FILE, O_RDONLY, 0644);
	if(0>fd){
		APP_DBG("File not exists\r\n");
		ret=readBDaddrTI();
	}else{
		APP_DBG("File exists\r\n");
		close(fd);
		ret=0;
	}

	return ret;
#else
	printf("error BT CHIP not defined!!!\n");
	return 0;
#endif
}

gboolean exit_cb(gpointer data)
{

	APP_DEBUG("Time out!!!\n");
	g_main_loop_quit(loop);

	return FALSE;
}
int main()
{
	loop=g_main_loop_new(NULL,FALSE);
	APP_DEBUG("Bluetooth Address Setting\n");
	make_bt_address(FALSE);

	/* When we get proper BT address by IMEI or
	 * randome BT address due to default IMEI
	 * We don't need to wait for telephony activation, timeout */
	if(success_make_bt_address_from_imei==0 || is_default_imei==TRUE)
		exit(0);

#ifdef IMEI_BASED_RAND_FEATURE
	g_timeout_add_seconds(10,exit_cb,NULL);
	g_main_loop_run(loop);
#endif

	return 0;
}
