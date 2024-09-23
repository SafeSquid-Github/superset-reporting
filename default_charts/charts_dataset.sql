##### Connections #####
# chart 1

SELECT timestamp, 
        FLOOR(client_connections_handled - client_connections_closed) AS ConcurrentClientConnections,
        FLOOR(client_threads_in_use) AS ConcurrentActiveRequests
FROM performance_logs;



##### Incoming Pressure #####
# chart 2

SELECT timestamp, 
        FLOOR(connections_handled_delta) AS NewIncomingConnections, 
        FLOOR(client_connections_in_pool) AS ConnectionInPool
FROM performance_logs;



##### Request Handling #####
# chart 3

SELECT timestamp, 
        FLOOR(transactions_handled_delta) AS client_transactions_handled, 
        FLOOR(outbound_connections_created_delta + outbound_connections_failed_delta + outbound_connection_pool_reused_delta + new_dns_queries_delta) AS OutboundConnectionsDemanded
FROM performance_logs;



##### WAN Pressure #####
# chart 4

SELECT timestamp, 
        FLOOR(outbound_connection_pool_reused_delta) AS outbound_connection_pool_reused, 
        FLOOR(outbound_connections_in_pool) AS outbound_connections_in_pool
FROM performance_logs;



##### Network Pressure #####
# chart 5

SELECT timestamp, 
        FLOOR(client_connections_handled - client_connections_closed + outbound_connections_created_delta + outbound_connections_in_pool) AS TotalTCPConnections, 
        FLOOR(client_connections_in_pool + outbound_connections_in_pool) AS IdleTCPConnections
FROM performance_logs;



##### Data Xfer #####
# chart 6

SELECT timestamp, 
        FLOOR(bytes_in_kbytes_delta / 1048576) AS BytesInMB, 
        FLOOR(bytes_out_kbytes_delta / 1048576) AS BytesOutMB
FROM performance_logs;



##### Caching #####
# chart 7

SELECT timestamp, 
        FLOOR(caching_objects_created_in_memory - caching_objects_removed_from_memory) AS CachingObjectsInMemory, 
        FLOOR(caching_objects_removed_from_memory_delta) AS caching_objects_removed_from_memory, 
        FLOOR(caching_objects_created_in_memory_delta) AS caching_objects_created_in_memory
FROM performance_logs;



##### DNS #####
# chart 8

SELECT timestamp, 
        FLOOR(new_dns_queries_delta) AS new_dns_queries, 
        FLOOR(dns_queries_reused_delta) AS dns_queries_reused
FROM performance_logs;



##### Threading Capacity #####
# chart 9

SELECT timestamp, 
        FLOOR(spare_client_threads) AS spare_client_threads, 
        FLOOR(client_threads_in_use) AS client_threads_in_use, 
        FLOOR(client_threads_in_waiting) AS client_threads_in_waiting
FROM performance_logs;



##### System Memory #####
# chart 10

SELECT timestamp, 
        FLOOR(total_system_memory_kbytes / 1048576) AS TotalSystemMemoryGB, 
        FLOOR(free_system_memory_kbytes / 1024) AS FreeSystemMemoryMB
FROM performance_logs;



##### SafeSquid Memory #####
# chart 11

SELECT timestamp, 
        FLOOR(safesquid_virtual_memory_kbytes / 1024) AS SafeSquidVirtualMemoryMB, 
        FLOOR(safesquid_library_memory_kbytes / 1024) AS SafeSquidLibraryMemoryMB, 
        FLOOR(safesquid_resident_memory_kbytes / 1024) AS SafeSquidResidentMemoryMB, 
        FLOOR(safesquid_shared_memory_kbytes / 1024) AS SafeSquidSharedMemoryMB, 
        FLOOR(safesquid_code_memory_kbytes / 1024) AS SafeSquidCodeMemoryMB, 
        FLOOR(safesquid_data_memory_kbytes / 1024) AS SafeSquidDataMemoryMB
FROM performance_logs;



##### Errors #####
# chart 12

SELECT timestamp, 
        FLOOR(dns_query_failures_delta) AS dns_query_failures, 
        FLOOR(outbound_connections_failed_delta) AS outbound_connections_failed, 
        FLOOR(threading_errors_delta) AS threading_errors
FROM performance_logs;



##### System Load #####
# chart 13

SELECT timestamp, 
        FLOOR(load_avg_1_min) AS load_avg_1_min, 
        FLOOR(load_avg_5_min) AS load_avg_5_min, 
        FLOOR(load_avg_15_min) AS load_avg_15_min
FROM performance_logs;



##### CPU Switching #####
# chart 14

SELECT timestamp, 
        FLOOR(running_processes) AS running_processes, 
        FLOOR(waiting_processes) AS waiting_processes
FROM performance_logs;



##### CPU Utilization 1 #####
# chart 15

SELECT timestamp, 
        FLOOR(total_time_delta * 1000) AS TotalCPUUseDeltaMsecs, 
        FLOOR(user_time_delta * 1000) AS UserTimeMsecs, 
        FLOOR(system_time_delta * 1000) AS SystemTimeMsecs
FROM performance_logs;



##### CPU Utilization 2 #####
# chart 16

SELECT timestamp, 
        FLOOR((total_time + total_time_delta) / elapsed_time) AS TotalCPUUseTrend, 
        FLOOR((user_time + user_time_delta) / elapsed_time) AS UserTimeTrend, 
        FLOOR((system_time + system_time_delta) / elapsed_time) AS SystemTimeTrend
FROM performance_logs;



##### Process Life #####
# chart 17

SELECT timestamp, 
        FLOOR(safesquid_virtual_memory_kbytes / 1024) AS SafeSquidVirtualMemoryMB, 
        FLOOR(elapsed_time) AS ProcessAge
FROM performance_logs;


