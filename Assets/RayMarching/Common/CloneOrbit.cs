namespace Nkd
{
    using UnityEngine;
    [ExecuteInEditMode] public class CloneOrbit : MonoBehaviour
    {
        public Transform cloneTarget;
        public float distance;

        void Update()
        {
            if( cloneTarget == null ) return;

            transform.position = cloneTarget.rotation * ( Vector3.forward * distance );

            transform.rotation = cloneTarget.rotation;

            //transform.LookAt( Vector3.zero , transform.up );
        }
    }
}

