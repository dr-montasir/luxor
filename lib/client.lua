local client = function(request)
    local html = [[
<!-- Luxor: Simple HTTP Client -->
<!-- Author: Montasir Mirghani <me@montasir.site> 2024-->
<!-- Send message as json body (method => post)-->
<!-- https://httpbin.org/post -->
<!-- Retrieve users collection (method => get) -->
<!-- https://jsonplaceholder.typicode.com/users -->
<!DOCTYPE html>
<html lang="en" x-data="httpClient()" x-init="init()"
  :class="darkMode ? 'bg-gray-800 text-white' : 'bg-gray-100 text-black'">

<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Simple HTTP Client</title>
  <script src="https://cdn.tailwindcss.com/3.4.16"></script>
  <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.8/dist/cdn.min.js" defer></script>
  <style>
    /* Add custom styles for the response area */
    .response-box {
      max-height: 300px;
      overflow-x: auto;
      overflow-y: auto;
    }

    .loader {
      display: none;
      /* Initially hidden */
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      z-index: 999;
    }
  </style>
</head>

<body class="p-6">
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold mb-4">Luxor <small>🔥 Simple HTTP Client 🔥</small></h1>
    <button @click="toggleDarkMode"
      :class="darkMode ? 'bg-gray-600 hover:bg-gray-500' : 'bg-gray-300 hover:bg-gray-400'"
      class="mb-5 font-bold dark:bg-gray-700 p-2 rounded" title="Toggle Dark/Light Mode">
      <span x-text="darkMode ? 'Light Mode' : 'Dark Mode'"></span>
    </button>
  </div>

  <form @submit.prevent="sendRequest" :class="darkMode ? 'bg-gray-900' : 'bg-gray-200'"
    class="bg-white dark:bg-gray-900 p-6 rounded-lg shadow-md">
    <div class="mb-4">
      <input type="text" x-model="url" placeholder="Enter URL" required
        :class="darkMode ? 'bg-gray-800 text-white' : 'bg-white'"
        class="border dark:border-gray-600 border-gray-300 p-2 w-full rounded">
    </div>
    <div class="mb-4">
      <select x-model="method" :class="darkMode ? 'bg-gray-800 text-white' : 'bg-white'"
        class="font-bold border dark:border-gray-600 border-gray-300 p-2 w-full rounded">
        <option value="GET">GET</option>
        <option value="POST">POST</option>
        <option value="PUT">PUT</option>
        <option value="PATCH">PATCH</option>
        <option value="DELETE">DELETE</option>
      </select>
    </div>
    <div class="mb-4">
      <textarea x-model="headers" placeholder="Headers (JSON format)"
        :class="darkMode ? 'bg-gray-800 text-white' : 'bg-white'"
        class="border dark:border-gray-600 border-gray-300 p-2 w-full rounded"></textarea>
    </div>
    <div class="mb-4">
      <input type="file" @change="handleFileChange" multiple :class="darkMode ? 'bg-gray-800 text-white' : 'bg-white'"
        class="border dark:border-gray-600 border-gray-300 p-2 w-full rounded">
    </div>
    <div class="mb-4" x-show="method !== 'GET' && method !== 'DELETE'">
      <textarea rows='5' x-model="body" placeholder="Body (JSON format, if applicable)"
        :class="darkMode ? 'bg-gray-800 text-white' : 'bg-white'"
        class="border dark:border-gray-600 border-gray-300 p-2 w-full rounded"></textarea>
    </div>
    <button type="submit"
      class="mt-2 font-bold bg-gray-600 text-[#61dafb] p-2 rounded hover:text-black hover:bg-[#61dafb]">Send
      Request</button>
  </form>

  <!-- Spinner Element -->
  <div id="loader" class="loader" role="status">
    <div class="w-8 h-8 border-8 border-dashed rounded-full animate-spin border-[#61dafb]"></div>
    <span class="sr-only">Loading...</span>
  </div>

  <div class="mt-6">
    <h2 class="text-xl font-semibold pb-4">Response:</h2>
    <div class="relative">
      <button @click="copyResponse"
        :class="darkMode ? 'bg-gray-700 hover:bg-gray-600' : 'bg-gray-300 hover:bg-gray-400'"
        class="absolute top-2 left-2 pl-1 p-2 rounded" title="Copy">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 6h12a2 2 0 012 2v12a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
            d="M8 6V4a2 2 0 012-2h8a2 2 0 012 2v2M12 12v4m0-4h4m-4 0H8" />
        </svg>
      </button>
      <pre x-text="response" :class="darkMode ? 'bg-gray-900' : 'bg-gray-200'" class="response-box p-10 rounded"></pre>
      <div x-show="copySuccess"
        class="font-bold absolute top-2 left-12 bg-green-500 text-white p-1 rounded transition-opacity duration-300">
        Response copied to clipboard!
      </div>
    </div>
  </div>

  <footer class="my-7" x-data="{ year: new Date().getFullYear() }">
    <div class="ml-7 mb-5 w-28 h-28">
      <a href='#'>
        <svg xmlns="http://www.w3.org/2000/svg" width="120" height="80" viewBox="0 0 60 40">
            <style>
                .title {
                font-family: Arial, sans-serif;
                font-size: 14px;
                font-weight: bold;
                fill: #ffffff;
                }

                .shadow {
                fill: rgba(0, 0, 185, 0.5);
                filter: drop-shadow(1px 1px 2px rgba(0, 0, 0, 0.2));
                }

                .curve {
                fill: none;
                stroke: #ffffff;
                stroke-width: 1.7;
                }

                .bg {
                fill: #00007c;
                stroke: #ffffff;
                stroke-width: 1;
                rx: 2;
                }
            </style>
            <rect class="bg" x="0" y="0" width="60" height="40" rx="5" />
            <!-- Text Shadow -->
            <text x="5" y="24" class="shadow">LUXOR</text>
            <!-- Main Text -->
            <text x="3" y="23" class="title">LUXOR</text>
            <path class="curve" d="M 55,20 Q 45,10 55,20 T 40,30" />
            </svg>
      </a>
    </div>
    <p class="text-gray-600">© <span x-text="year"></span> <a class="underline" href="https://www.luxor-web.site" target="_blank">Luxor Web</a> | <a class="underline" href="https://github.com/dr-montasir" target="_blank">Dr. Montasir</a>. All rights reserved.</p>
  </footer>

  <script>
    function httpClient() {
      return {
        url: '',
        method: 'GET',
        headers: '',
        body: '',
        files: [],
        response: '',
        copySuccess: false,
        darkMode: false,
        loading: false,
        timeoutId: null,

        init() {
          this.darkMode = JSON.parse(localStorage.getItem('darkMode')) || false;
        },

        toggleDarkMode() {
          this.darkMode = !this.darkMode;
          localStorage.setItem('darkMode', JSON.stringify(this.darkMode));
        },

        handleFileChange(event) {
          this.files = Array.from(event.target.files);
        },

        async sendRequest() {
          const loader = document.getElementById("loader");
          loader.style.display = "block"; // Show spinner
          this.loading = true; // Set loading state
          this.response = ''; // Clear previous response

          this.timeoutId = setTimeout(() => {
            this.loading = false;
            loader.style.display = "none"; // Hide spinner
            this.response = 'Error: Request timed out after 3 minutes.';
          }, 180000); // Timeout after 3 minutes

          try {
            const options = {
              method: this.method,
              headers: {
                'Content-Type': this.method === 'POST' || this.method === 'PUT' || this.method === 'PATCH' ? 'application/json' : undefined,
                ...this.parseHeaders(this.headers)
              }
            };

            if (this.method === 'POST' || this.method === 'PUT' || this.method === 'PATCH') {
              options.body = JSON.stringify(this.body ? JSON.parse(this.body) : {});
            }

            const response = await fetch(this.url, options);
            clearTimeout(this.timeoutId); // Clear timeout if response is received

            if (!response.ok) {
              throw new Error(`HTTP error! Status: ${response.status}`);
            }

            const responseText = await response.text(); // Read response as text
            console.log('Raw response:', responseText); // Log the raw response

            this.loading = false; // Hide loading indicator
            loader.style.display = "none"; // Hide spinner

            if (response.headers.get('Content-Type').includes('application/json')) {
              // Clean up the response to make it valid JSON
              const cleanedResponseText = responseText.replace(/ObjectId\("([^"]+)"\)/, '\$1');
              const responseData = JSON.parse(cleanedResponseText); // Parse JSON
              this.response = JSON.stringify(responseData, null, 2);
            } else {
              this.response = responseText; // Handle as plain text
            }
          } catch (error) {
            this.loading = false;
            loader.style.display = "none"; // Hide spinner if error occurs
            this.response = `Error: ${error.message}`;
          }
        },
        parseHeaders(headersString) {
          try {
            return JSON.parse(headersString);
          } catch (e) {
            return {};
          }
        },

        copyResponse() {
          navigator.clipboard.writeText(this.response).then(() => {
            this.copySuccess = true;
            setTimeout(() => {
              this.copySuccess = false;
            }, 5000);
          }).catch(err => {
            console.error('Failed to copy: ', err);
          });
        }
      }
    }
  </script>
</body>

</html>]]

    return "200", "OK", {["Content-Type"] = "text/html; charset=utf-8"}, html
end

return client