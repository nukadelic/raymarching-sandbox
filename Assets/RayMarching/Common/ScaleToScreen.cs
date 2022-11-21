namespace nkd
{
    // ! note : make sure parent gameobject is Camera 

    using UnityEngine;
    
    [ExecuteInEditMode] public class ScaleToScreen : MonoBehaviour
    {
        public float offsetDistance = 1;

        public Vector2 meshSize = new Vector2( 1, 1 );

        public Camera parent;

        public bool rotateRight = false;

        void Update()
        {
            if( parent == null ) return;

            transform.localPosition = Vector3.forward * offsetDistance;

            transform.localRotation = Quaternion.identity;

            var bottom_left = parent.ViewportToWorldPoint(new Vector3(0, 0, offsetDistance), Camera.MonoOrStereoscopicEye.Mono);
            var top_right = parent.ViewportToWorldPoint(new Vector3(1, 1, offsetDistance), Camera.MonoOrStereoscopicEye.Mono);
            var diagonal = top_right - bottom_left;
            var length = diagonal.magnitude;
            diagonal = parent.transform.InverseTransformDirection(diagonal.normalized);
            diagonal = diagonal * length;
            diagonal.z = 1;

            if( rotateRight )
            {
                var x = diagonal.x;
                diagonal.x = diagonal.y;
                diagonal.y = x;

                transform.localRotation *= Quaternion.Euler( 0, 0, -90 );
            }

            transform.localScale = meshSize * diagonal;
        }

        private void OnDrawGizmos()
        {
            if( parent == null ) return;

            Gizmos.DrawLine( transform.position , transform.position - transform.forward * offsetDistance );

            var bottom_left = parent.ViewportToWorldPoint( new Vector3( 0 , 0 , offsetDistance ), Camera.MonoOrStereoscopicEye.Mono );
            var top_right = parent.ViewportToWorldPoint( new Vector3( 1 , 1 , offsetDistance ), Camera.MonoOrStereoscopicEye.Mono );
            var diagonal = top_right - bottom_left;
            var length = diagonal.magnitude;
            diagonal = parent.transform.InverseTransformDirection( diagonal.normalized );
            diagonal = diagonal * length;

            Gizmos.color = Color.red;
            Gizmos.DrawCube( bottom_left , Vector3.one * 10 );
            Gizmos.DrawCube( top_right   , Vector3.one * 10 );
            Gizmos.DrawLine( bottom_left , top_right );
            // Gizmos.DrawWireCube( transform.position , transform.rotation * new Vector3( diagonal.x, diagonal.y, 0.1f ) );
        }
    }
}

