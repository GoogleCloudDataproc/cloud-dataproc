import tensorflow as tf
import sys

print("Get GPU Details:")
gpus = tf.config.list_physical_devices('GPU')
print(gpus)

if not gpus:
    print("No GPU devices found. Please install GPU version of TF.", file=sys.stderr)
    # Depending on the use case, you might want to exit here.
    # sys.exit(1)
else:
    print(f"Found {len(gpus)} GPU(s):")
    for gpu in gpus:
        print(f"  - {gpu.name}")

# The tf.test.gpu_device_name() is deprecated but can be useful for a quick default check
try:
    # This function might not exist in very new TF versions, hence the try/except
    if tf.test.gpu_device_name():
        print(f"Default GPU Device: {tf.test.gpu_device_name()}")
    else:
        print("tf.test.gpu_device_name() returned empty.")
except AttributeError:
    print("tf.test.gpu_device_name() is not available in this version of TensorFlow.")


# The modern way to check for CUDA-enabled GPUs is just to list them.
# The 'cuda_only' and minimum compute capability checks are effectively deprecated
# as the Python bindings are tightly coupled with CUDA. If a GPU is found,
# it's a CUDA-enabled GPU that TF can use.
is_cuda_gpu_available = len(tf.config.list_physical_devices('GPU')) > 0
print(f"CUDA-enabled GPUs available: {is_cuda_gpu_available}")


from tensorflow.python.client import device_lib

def get_available_gpus_detailed():
    local_device_protos = device_lib.list_local_devices()
    return [x.name for x in local_device_protos if x.device_type == 'GPU']

print("\nDetailed GPU device list from device_lib:")
print(get_available_gpus_detailed())
