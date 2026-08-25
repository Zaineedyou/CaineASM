#include <curl/curl.h>
#include <errno.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

static CURL *gateway;
static char last_error[256];

static void set_error(const char *context, CURLcode code) {
    snprintf(last_error, sizeof(last_error), "%s: %s", context, curl_easy_strerror(code));
}

int secure_transport_init(void) {
    CURLcode code = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (code != CURLE_OK) {
        set_error("curl_global_init", code);
        return -1;
    }
    return 0;
}

const char *secure_transport_last_error(void) {
    return last_error[0] ? last_error : "ok";
}

int secure_gateway_connect(const char *url) {
    CURLcode code;
    if (gateway) {
        curl_easy_cleanup(gateway);
        gateway = NULL;
    }
    gateway = curl_easy_init();
    if (!gateway) return -ENOMEM;

    curl_easy_setopt(gateway, CURLOPT_URL, url);
    curl_easy_setopt(gateway, CURLOPT_CONNECT_ONLY, 2L);
    curl_easy_setopt(gateway, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(gateway, CURLOPT_SSL_VERIFYHOST, 2L);
    curl_easy_setopt(gateway, CURLOPT_USERAGENT, "CaineASM/0.1");
    curl_easy_setopt(gateway, CURLOPT_TIMEOUT_MS, 15000L);
    code = curl_easy_perform(gateway);
    if (code != CURLE_OK) {
        set_error("gateway connect", code);
        curl_easy_cleanup(gateway);
        gateway = NULL;
        return -(int)code;
    }
    return 0;
}

long secure_gateway_send_text(const char *data, size_t length) {
    size_t sent = 0;
    CURLcode code;
    if (!gateway) return -ENOTCONN;
    code = curl_ws_send(gateway, data, length, &sent, 0, CURLWS_TEXT);
    if (code != CURLE_OK || sent != length) {
        set_error("gateway send", code);
        return code == CURLE_OK ? -EIO : -(long)code;
    }
    return (long)sent;
}

long secure_gateway_recv_text(char *out, size_t capacity, size_t *out_length) {
    const struct curl_ws_frame *meta = NULL;
    size_t received = 0;
    CURLcode code;
    if (!gateway) return -ENOTCONN;
    code = curl_ws_recv(gateway, out, capacity, &received, &meta);
    if (code == CURLE_AGAIN) return -EAGAIN;
    if (code != CURLE_OK) {
        set_error("gateway receive", code);
        return -(long)code;
    }
    if (!meta || !(meta->flags & CURLWS_TEXT) || meta->bytesleft != 0) return -EMSGSIZE;
    *out_length = received;
    return (long)received;
}

void secure_gateway_close(void) {
    if (gateway) {
        curl_easy_cleanup(gateway);
        gateway = NULL;
    }
}

struct response_buffer {
    char *data;
    size_t capacity;
    size_t length;
};

static size_t receive_body(char *data, size_t size, size_t count, void *opaque) {
    struct response_buffer *buffer = opaque;
    size_t bytes = size * count;
    if (bytes > buffer->capacity - buffer->length - 1) return 0;
    memcpy(buffer->data + buffer->length, data, bytes);
    buffer->length += bytes;
    buffer->data[buffer->length] = '\0';
    return bytes;
}

long secure_https_post_json(const char *url, const char *authorization,
                            const char *body, size_t body_length,
                            char *response, size_t response_capacity,
                            long *status_out) {
    CURL *easy = curl_easy_init();
    struct curl_slist *headers = NULL;
    struct response_buffer output = {response, response_capacity, 0};
    CURLcode code;
    long status = 0;
    if (!easy || !response || response_capacity < 2) return -EINVAL;

    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, authorization);
    curl_easy_setopt(easy, CURLOPT_URL, url);
    curl_easy_setopt(easy, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(easy, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(easy, CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)body_length);
    curl_easy_setopt(easy, CURLOPT_SSL_VERIFYPEER, 1L);
    curl_easy_setopt(easy, CURLOPT_SSL_VERIFYHOST, 2L);
    curl_easy_setopt(easy, CURLOPT_TIMEOUT_MS, 30000L);
    curl_easy_setopt(easy, CURLOPT_WRITEFUNCTION, receive_body);
    curl_easy_setopt(easy, CURLOPT_WRITEDATA, &output);
    code = curl_easy_perform(easy);
    curl_easy_getinfo(easy, CURLINFO_RESPONSE_CODE, &status);
    curl_slist_free_all(headers);
    curl_easy_cleanup(easy);
    if (status_out) *status_out = status;
    if (code != CURLE_OK) {
        set_error("https post", code);
        return -(long)code;
    }
    return (long)output.length;
}
