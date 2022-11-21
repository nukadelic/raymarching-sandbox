namespace Nkd
{
    using UnityEngine;
    
    public class Accelerometer : MonoBehaviour
    {
        Vector3 gravity = new Vector3(0, -1, 0);

        void Update()
        {
            Vector3 acceleration = Input.acceleration;
            
            acceleration.z *= -1;

            transform.rotation = Quaternion.FromToRotation( gravity, acceleration );
        }
    }
}